# Exports a family of low-poly pets for the game (decision 118) as one GLB: each kind's body once
# (the game makes all ten variants of it: the tier only grows it and repaints its shell) and the kit
# of outfit pieces the game dresses the pets in, by a roll from the tier's pools (World/AlienOutfit).
#
# Node names carry everything (lune/aliens.luau unpacks them):
#   <kind>|<role>_<n>|<paint code>                     a body part;
#   <kind>|meta1|<zone>|<family>|<signature>          the kind's data (tiny marker);
#   <kind>|meta2|<glow>|<core>|<shell>                its colours;
#   <kind>|anchor|<Slot>|<scale>                       where an outfit slot sits on the body;
#   <kind>|hinge|<hinge name>                          a point a moving part turns on (hingeLegLA…);
#   kit|<piece>|<role>_<n>|<paint code>                a part of an outfit piece;
#   kit|<piece>|origin                                 the piece's origin (it goes on a slot's point);
#   kit|<piece>|dust<L|R><n>                           a fairy wing's dust point.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/lowpoly/export_lowpoly_roblox.py -- <out.glb> [family,family… | all] [kit]

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import lowpoly_dress as dress  # noqa: E402
import lowpoly_fit as fitting  # noqa: E402
import lowpoly_kit as kit  # noqa: E402
import lowpoly_pets as pets  # noqa: E402
import robo  # noqa: E402
import robo_kinds  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "out/lowpoly/pack-lowpoly-slime.glb"
# Families to pack (comma separated, or "all"), and whether to pack the outfit kit too ("kit"): the
# kit goes up once, with the first pack, so its meshes are one set for the whole game.
FAMILIES = ARGS[1].split(",") if len(ARGS) > 1 else ["slime"]
WITH_KIT = len(ARGS) > 2 and ARGS[2] == "kit"
STYLE = "faceted"
SPACING = 8.0
KIT_ROW = 30.0
# A meteor's molten shell wears the lava crack texture on box-projected UVs (export_robo_roblox.py).
LAVA_TILE = 1.5
# Shell sources the game repaints by tier (gold) and variant (lava): they need UVs for the lava.
SHELLS = ("Shell", "Candy", "Crystal")
# Parts kept one by one (the game reads them one by one): the dome sets the jelly's floor, a flame or
# jet stand-in plays particles from its own place. A role's eyes join into one part: they blink
# together (World/RigMotion), and a swarm's drones had two eye parts each.
KEEP_SOURCES = {"Dome", "Flame", "Jet"}


def source_of(code):
    return code.rsplit(",", 1)[1]


def box_uvs(obj):
    """World-unit box-projected UVs, as the lava wants them (one crack size all over the pet)."""
    mesh = obj.data
    layer = mesh.uv_layers.new(name="UVMap")
    world = obj.matrix_world
    rotation = world.to_3x3()
    for polygon in mesh.polygons:
        normal = rotation @ polygon.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        u, v = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in polygon.loop_indices:
            point = world @ mesh.vertices[mesh.loops[loop].vertex_index].co
            layer.data[loop].uv = (point[u] / LAVA_TILE, point[v] / LAVA_TILE)


def marker(name, location):
    """A tiny tetrahedron carrying a name (a glTF node needs geometry to reach Roblox)."""
    mesh = bpy.data.meshes.new(name)
    s = 0.02
    mesh.from_pydata([(0, 0, 0), (s, 0, 0), (0, s, 0), (0, 0, s)], [], [(0, 1, 2), (0, 1, 3), (0, 2, 3), (1, 2, 3)])
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    return obj


def z_span(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return min(c.z for c in corners), max(c.z for c in corners)


def join(objects, prefix, floor=None):
    """Objects of one role and paint become one mesh (each object's own copy of its shared mesh first,
    so the library is left alone). Returns the joined objects, named <prefix>|<role>_<n>|<code>."""
    groups = {}
    for obj in objects:
        role = obj["role"] if obj["role"] not in ("eye", "dome") else "body"
        code = obj["paint"]
        key = (role, code)
        if source_of(code) in KEEP_SOURCES or role == "flame":
            key = (role, code, obj.name)
        elif floor is not None:
            low, high = z_span(obj)
            key = (role, code, "above" if low > floor else "below" if high < floor else obj.name)
        groups.setdefault(key, []).append(obj)
    joined = []
    for index, (key, group) in enumerate(sorted(groups.items(), key=lambda item: str(item[0]))):
        for obj in group:
            obj.data = obj.data.copy()
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        if len(group) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        role, code = key[0], key[1]
        obj.name = obj.data.name = f"{prefix}|{role}_{index + 1}|{code}"
        if source_of(code) in SHELLS:
            box_uvs(obj)
        joined.append(obj)
    return joined


def jelly_floor(objects):
    for obj in objects:
        if source_of(obj["paint"]) == "Dome":
            low, high = z_span(obj)
            return (low + high) / 2 - (high - low) * 0.3
    return None


def rgb255(colour):
    return ",".join(str(round(pets.srgb(v) * 255)) for v in colour[:3])


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    library = kit.Library(STYLE)
    kinds = [k for k in robo_kinds.KINDS if "all" in FAMILIES or k[2] in FAMILIES]
    finished = []
    # The kit's pieces as geometry, to fit the back slots to each body (lowpoly_fit.py).
    fitter = pets.Context(kit.Pet(library, bpy.context.scene.collection), robo.theme("debris")["colours"], 2, False, STYLE)
    geometry = fitting.kit_geometry(fitter)
    for index, kind in enumerate(kinds):
        kind_id = kind[0]
        collection = bpy.data.collections.new(kind_id)
        bpy.context.scene.collection.children.link(collection)
        pet = pets.build(kind, 2, STYLE, library, False, collection, body_only=True)
        bpy.context.view_layer.update()
        points = fitting.fit(pet.info, pet.objects, geometry, lambda note, kind_id=kind_id: print(f"FIT {kind_id}: {note}"))
        x = index * SPACING
        for obj in pet.objects:
            obj.location.x += x
        bpy.context.view_layer.update()
        parts = join(pet.objects, kind_id, jelly_floor(pet.objects))
        colours = robo.theme(kind[3], kind[4])["colours"]
        signature = "+".join(part.__name__ for part in kind[6])
        nodes = list(parts)
        nodes.append(marker(f"{kind_id}|meta1|{kind[3]}|{kind[2]}|{signature}", (x, 0, -1)))
        nodes.append(marker(f"{kind_id}|meta2|{rgb255(colours['glow'])}|{rgb255(colours['core'])}|{rgb255(colours['shell'])}", (x, 0, -1)))
        for slot, (point, scale) in points.items():
            nodes.append(marker(f"{kind_id}|anchor|{slot}|{scale:.3f}", (point[0] + x, point[1], point[2])))
        for name, point in pet.ctx.hinges:
            nodes.append(marker(f"{kind_id}|hinge|{name}", (point[0] + x, point[1], point[2])))
        for obj in nodes:
            if len(obj.name) > 62:
                raise ValueError(f"name too long for Blender: {obj.name}")
        finished += nodes
        print(f"BODY {kind_id}: {len(parts)} parts, {sum(len(p.data.polygons) for p in parts)} faces")
    # The kit: one of each piece in a row behind the bodies.
    if not WITH_KIT:
        finish(finished)
        return
    collection = bpy.data.collections.new("Kit")
    bpy.context.scene.collection.children.link(collection)
    holder = kit.Pet(library, collection)
    ctx = pets.Context(holder, robo.theme("debris")["colours"], 2, False, STYLE)
    for index, (name, (placements, dust)) in enumerate(sorted(dress.kit(ctx).items())):
        origin = Vector((index * 4.0, KIT_ROW, 0))
        objects = []
        for mesh, point, scale, key, rotation, role in placements:
            objects.append(ctx.put(mesh, tuple(origin + Vector(point)), scale, key, rotation, role))
        bpy.context.view_layer.update()
        parts = join(objects, f"kit|{name}")
        finished += parts
        finished.append(marker(f"kit|{name}|origin", tuple(origin)))
        for marker_name, point in dust:
            finished.append(marker(f"kit|{name}|{marker_name}", tuple(origin + Vector(point))))
        print(f"PIECE {name}: {len(parts)} parts, {sum(len(p.data.polygons) for p in parts)} faces")
    finish(finished)


def finish(finished):
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in finished)
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    options = dict(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=True, export_materials="NONE")
    bpy.ops.export_scene.gltf(**options)
    meshes = [obj for obj in finished if obj.type == "MESH" and "|meta" not in obj.name and "|anchor|" not in obj.name and not obj.name.endswith("|origin") and "|dust" not in obj.name]
    print("PACKED", OUT, len(finished), "nodes,", len(meshes), "meshes,", os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    main()
