# Checks the robot pets for misplaced parts, without Studio: builds each pet as the export does and
# reports parts that float in the air (touch nothing), parts hidden whole inside another part, and
# parts of different outfit pieces that cut through each other (a shoulder plate through a drone's
# wing, an emblem through the visor).
#
# Every part is labelled with the piece that made it (the family's body, the hull details, the
# thruster pack, the wings, a kind's signature...), so a report names who placed what. Parts that
# float by design (effects, orbits, rays, a swarm's little drones circling) are left out of the
# floating check.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/check_robo_parts.py -- <out.tsv> [kind ...]
# Writes one line per finding: kind, variant, problem, part, other part.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import robo  # noqa: E402
import robo_kinds  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "check_robo_parts.tsv"
ONLY = set(ARGS[1:])
VARIANTS = [("0", 0, False), ("1", 1, False), ("2", 2, False), ("3", 3, False), ("4", 4, False), ("m4", 4, True)]

# A part farther than this from every other part floats.
TOUCH = 0.03
# Roles that float by design: effects, orbiting things, the rays fan, markers.
LOOSE_ROLES = {"fx", "orbit", "rays", "halo", "ring", "wisp", "flame"}
LOOSE_ROLE_PREFIXES = ("hinge", "dust", "drone")
# Pieces that float by design: a black hole hovering over the head, rocks and a pad held by
# gravity, northern lights over the back, a mother worm's babies beside her.
LOOSE_GROUPS = {"tier_ring", "motes", "orbit", "sunburst", "flair_horizon", "sig:void_core", "sig:gravity", "sig:aurora", "sig:babies"}
# Body parts that float by design (a ray's hover glow under it).
LOOSE_MATERIALS = ("Hover", "Core")
# See-through parts: what sits inside them shows, so it is not hidden.
CLEAR_MATERIALS = ("Dome", "Glass", "Crystal", "Jelly")
# Pieces whose parts may cut through anything: see-through or glowing, they read as light.
SOFT_GROUPS = {"wings", "tier_ring", "motes", "orbit", "sunburst", "meteor_fire", "flair_horizon", "sig:frill", "sig:babies"}
# Body parts an outfit piece must not cut through (the face, a drone's or a ray's wings, fins).
FACE_MATERIALS = ("Visor", "EyeLight", "Wing", "Rim", "Porthole")


def _labelled(function, label):
    """`function`, labelling every object it makes with `label` (inner labels win)."""
    def run(*args, **kwargs):
        before = set(bpy.data.objects)
        try:
            return function(*args, **kwargs)
        finally:
            for obj in set(bpy.data.objects) - before:
                if "group" not in obj:
                    obj["group"] = label
    return run


for name in ("details", "pack", "beacon", "wings", "orbit", "motes", "crown", "sunburst", "meteor_fire", "tier_ring"):
    setattr(robo, name, _labelled(getattr(robo, name), name))
for zone, flair in list(robo.FLAIR.items()):
    robo.FLAIR[zone] = _labelled(flair, flair.__name__)
for family, make in list(robo.FAMILIES.items()):
    robo.FAMILIES[family] = _labelled(make, "body")


def material_of(obj):
    data = getattr(obj, "data", None)
    materials = getattr(data, "materials", None)
    return materials[0].name.split(".")[0] if materials and materials[0] else "?"


def world_tree(obj, depsgraph):
    """The part's evaluated surface in world space, its bounds, and its vertices."""
    evaluated = obj.evaluated_get(depsgraph)
    try:
        mesh = evaluated.to_mesh()
    except RuntimeError:
        return None
    if mesh is None or not mesh.polygons:
        evaluated.to_mesh_clear()
        return None
    matrix = obj.matrix_world
    verts = [matrix @ v.co for v in mesh.vertices]
    polys = [tuple(p.vertices) for p in mesh.polygons]
    evaluated.to_mesh_clear()
    low = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
    high = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
    return BVHTree.FromPolygons(verts, polys), low, high, verts


def near(a, b, margin):
    return all(a[1][i] - margin <= b[2][i] and b[1][i] - margin <= a[2][i] for i in range(3))


def loose(obj):
    role = obj.get("role", "body")
    return (role in LOOSE_ROLES or role.startswith(LOOSE_ROLE_PREFIXES) or obj.get("group") in LOOSE_GROUPS
            or material_of(obj).startswith(LOOSE_MATERIALS))


def label(obj):
    return f"{obj.get('group', '?')}:{material_of(obj)}"


def check(kind, variant, tier, meteor):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    signature = [_labelled(part, "sig:" + part.__name__) for part in kind[6]]
    robo_kinds.build((*kind[:6], signature, *kind[7:]), tier, 0.0, 0.0, meteor)
    return findings()


def findings():
    """What is wrong with the parts in the scene: one built pet (or guardian), at the origin."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    parts = []
    for obj in bpy.context.scene.objects:
        # Effect stand-ins never reach the game (particles play there instead).
        if obj.type not in ("MESH", "CURVE") or obj.get("role") == "fx":
            continue
        tree = world_tree(obj, depsgraph)
        if tree:
            parts.append((obj, tree))
    problems = []
    links = {id(obj): set() for obj, _ in parts}
    crossed = set()
    for i, (a, ta) in enumerate(parts):
        for b, tb in parts[i + 1:]:
            if not near(ta, tb, TOUCH):
                continue
            if ta[0].overlap(tb[0]):
                crossed.update((id(a), id(b)))
                links[id(a)].add(id(b))
                links[id(b)].add(id(a))
                ga, gb = a.get("group"), b.get("group")
                if ga == gb or ga in SOFT_GROUPS or gb in SOFT_GROUPS or loose(a) or loose(b):
                    continue
                # Outfit pieces cutting each other, or an outfit piece through the face or a wing.
                if ga != "body" and gb != "body":
                    problems.append(("cuts", label(a), label(b)))
                elif (ga == "body" and material_of(a).startswith(FACE_MATERIALS)) or (gb == "body" and material_of(b).startswith(FACE_MATERIALS)):
                    problems.append(("cuts face", label(a), label(b)))
            elif min(tb[0].find_nearest(v)[3] or 1.0 for v in ta[3]) < TOUCH:
                links[id(a)].add(id(b))
                links[id(b)].add(id(a))
    by_id = {id(obj): (obj, tree) for obj, tree in parts}
    # A part touching nothing may sit whole inside another one: hidden.
    for obj, tree in parts:
        if links[id(obj)] or loose(obj):
            continue
        centre = (tree[1] + tree[2]) / 2
        for other, other_tree in parts:
            if other is obj or not near(tree, other_tree, 0.0):
                continue
            found = other_tree[0].find_nearest(centre)
            if found[0] is not None and (centre - found[0]).dot(found[1]) < 0:
                if not material_of(other).startswith(CLEAR_MATERIALS):
                    problems.append(("hidden", label(obj), label(other)))
                links[id(obj)].add(id(other))
                break
    # Pieces held together but not to the pet float as a whole (a crown over a crab's shell): the
    # pet is the group holding its biggest part; every other group of fixed parts floats.
    fixed = [obj for obj, _ in parts if not loose(obj)]
    seen, groups = set(), []
    for obj in fixed:
        if id(obj) in seen:
            continue
        group, stack = [], [id(obj)]
        seen.add(id(obj))
        while stack:
            current = stack.pop()
            group.append(current)
            for other in links[current]:
                if other not in seen and not loose(by_id[other][0]):
                    seen.add(other)
                    stack.append(other)
        groups.append(group)

    def size(key):
        low, high = by_id[key][1][1], by_id[key][1][2]
        return (high - low).length

    anchor = max(groups, key=lambda group: max(size(key) for key in group))
    for group in groups:
        if group is anchor:
            continue
        names = sorted({label(by_id[key][0]) for key in group})
        # Where it hangs, for finding it (the pet stands at the origin, facing -y).
        low, high = by_id[group[0]][1][1], by_id[group[0]][1][2]
        at = (low + high) / 2
        problems.append(("floats", "+".join(names[:3]), f"{len(group)} at {at.x:.2f},{at.y:.2f},{at.z:.2f}"))
    return problems


def main():
    rows = []
    for kind in robo_kinds.KINDS:
        if ONLY and kind[0] not in ONLY:
            continue
        for variant, tier, meteor in VARIANTS:
            for problem, part, other in sorted(set(check(kind, variant, tier, meteor))):
                rows.append(f"{kind[0]}\t{variant}\t{problem}\t{part}\t{other}")
        print("Checked", kind[0], flush=True)
    with open(OUT, "w", encoding="utf-8") as file:
        file.write("\n".join(rows) + "\n")
    print("Findings", len(rows), "->", OUT)


if __name__ == "__main__":
    main()
