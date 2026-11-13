# Fitting the outfit's back slots to a body (decision 118): the wings' hinges and size and the
# legendary star's place, so that no pair of wings, in any phase of the game's beat, crosses the
# other, sinks into the body or runs into a piece worn with it (the head pieces, the crown, the
# halo, the star). The user found wings crossing, beating from their middle and half inside narrow
# bodies (2026-11-13); this is the check that keeps them out, and the export fits every kind with it.
#
# The beat is the game's (World/RigMotion): about the hinge, `CFrame.Angles(0, -out * swing,
# out * 0.12 * beat)`, swing = -0.17 + 0.3 * beat, in Roblox axes; Blender's are X = -x, Y = z, Z = y.

import bpy
import lowpoly_dress as dress
import lowpoly_wings as wingkit
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

# The beat's phases checked: down, middle, up and between.
BEATS = [-1.0, -0.5, 0.0, 0.5, 1.0]
# The sizes a pair is worn at (OutfitDress.WINGS, EPIC_WINGS): a legendary's, an epic's, and a
# rare's small pair (angel and butterfly).
SIZES = {"butterfly": [1.0, 0.85, 0.6], "angel": [1.0, 0.85, 0.6], "dragon": [1.0, 0.85], "crystal": [1.0, 0.85], "fairy": [1.0, 0.85]}
# What a pet may wear with its wings: the slot each sits on and the wing sizes it is worn with
# (lowpoly_dress.POOLS: the head pieces up to epic, the crown and the star only on a legendary, the
# halo from rare up; the star is fitted on its own).
WORN_WITH = {
    "horns": ("Head", (0.85, 0.6)),
    "crest": ("Head", (0.85, 0.6)),
    "feelers": ("Head", (0.85, 0.6)),
    "crown": ("Crown", (1.0,)),
    "halo": ("Halo", (1.0, 0.85, 0.6)),
}
# Body parts never seen (stand-ins) and parts that orbit away from the body.
HIDDEN_SOURCES = ("Flame", "Jet")
LOOSE_ROLES = ("orbit",)
# The share of a wing's points that may sit inside the body: its root, on the surface, dips a little.
SUNK = 0.06
# A hinge sits this far under the surface it was put on, so the root is not seen floating.
INSET = 0.03
# Where the hinges may go: down the back from the hull's point (in body radii, each put back on the
# surface), then out from the surface a little, then the pair smaller. A wing pushed far from the
# body hangs in the air, so lowering and shrinking come before a long push.
LOWER_STEPS = [0.0, 0.1, 0.2, 0.3, 0.4]
PUSH_LIMIT = 0.2
PUSH_STEP = 0.05
SHRINK_STEP = 0.92
SHRINK_LIMIT = 0.6
# How far back the star may stand behind its place, in body radii, and how small it may get.
STAR_PUSH_LIMIT = 1.2
STAR_SHRINK_LIMIT = 0.6

RAY = Vector((0.123, 0.456, 0.88)).normalized()


def geometry(objects):
    """World-space vertices and polygons of `objects`, as one list."""
    verts, polys = [], []
    for obj in objects:
        matrix = obj.matrix_world
        base = len(verts)
        verts += [matrix @ v.co for v in obj.data.vertices]
        polys += [[base + i for i in p.vertices] for p in obj.data.polygons]
    return verts, polys


def kit_geometry(ctx):
    """Every outfit piece built at the origin at scale 1, as the kit exports it: name -> (verts, polys)."""
    result = {}
    for name, (placements, _) in dress.kit(ctx).items():
        objects = [ctx.put(mesh, point, scale, key, rotation, role) for mesh, point, scale, key, rotation, role in placements]
        bpy.context.view_layer.update()
        result[name] = geometry(objects)
        for obj in objects:
            bpy.data.objects.remove(obj)
    return result


def visible(obj):
    code = str(obj.get("paint", ""))
    return obj.get("role") not in LOOSE_ROLES and not any(code.endswith(source) for source in HIDDEN_SOURCES)


class Body:
    """A body's parts as trees for the checks: each part on its own (inside tests) and all together."""

    def __init__(self, objects):
        self.parts = []
        shown = [obj for obj in objects if visible(obj)]
        for obj in shown:
            verts, polys = geometry([obj])
            if polys:
                self.parts.append(BVHTree.FromPolygons(verts, polys))
        self.tree = BVHTree.FromPolygons(*geometry(shown))

    def inside(self, point):
        """A ray from `point` crosses some part's surface an odd number of times (normals don't matter)."""
        for tree in self.parts:
            crossings, origin = 0, Vector(point)
            while crossings < 64:
                hit = tree.ray_cast(origin, RAY, 1000.0)
                if hit[0] is None:
                    break
                crossings += 1
                origin = hit[0] + RAY * 1e-4
            if crossings % 2 == 1:
                return True
        return False

    def outermost(self, origin, direction, reach):
        """The farthest surface point from `origin` along `direction` within `reach`, or None."""
        start = Vector(origin) + direction * reach
        hit = self.tree.ray_cast(start, -direction, reach)
        return hit[0]


def beat_matrix(side, beat):
    """The game's turn of a wing about its hinge, in Blender's axes."""
    out = 1 if side < 0 else -1  # the left hinge (Blender -x) is Roblox +X
    swing = -0.17 + 0.3 * beat
    return Matrix.Rotation(-out * swing, 4, "Z") @ Matrix.Rotation(out * 0.12 * beat, 4, "Y")


def wing_name(kind, side):
    return "wing" + kind[0].upper() + kind[1:] + ("L" if side < 0 else "R")


def wing_tree(geometry_by_name, kind, side, hinge, span, beat):
    verts, polys = geometry_by_name[wing_name(kind, side)]
    turn = beat_matrix(side, beat)
    moved = [Vector(hinge) + (turn @ (v * span).to_4d()).to_3d() for v in verts]
    return moved, BVHTree.FromPolygons(moved, polys)


def piece_tree(geometry_by_name, name, at, scale):
    verts, polys = geometry_by_name[name]
    return BVHTree.FromPolygons([Vector(at) + v * scale for v in verts], polys)


def wing_faults(points, body, geometry_by_name, beats=BEATS, kinds=None):
    """What goes wrong with the wings on these points: [(wing kind, size, fault)], fault one of
    "cross", "body <share>", "<piece>"; and the worst sunk share."""
    worn = {name: (piece_tree(geometry_by_name, name, *points[slot]), sizes) for name, (slot, sizes) in WORN_WITH.items()}
    faults, worst = [], 0.0
    for kind in kinds or wingkit.WINGS:
        for size in SIZES[kind]:
            for beat in beats:
                trees = []
                for side in (-1, 1):
                    hinge, span = points["Wing" + ("L" if side < 0 else "R")]
                    moved, tree = wing_tree(geometry_by_name, kind, side, hinge, span * size, beat)
                    trees.append(tree)
                    sunk = sum(1 for v in moved if body.inside(v)) / len(moved)
                    worst = max(worst, sunk)
                    if sunk > SUNK:
                        faults.append((kind, size, f"body {sunk:.2f}"))
                    faults += [(kind, size, name) for name, (other, sizes) in worn.items() if size in sizes and tree.overlap(other)]
                if trees[0].overlap(trees[1]):
                    faults.append((kind, size, "cross"))
    return faults, worst


def star_faults(points, geometry_by_name, beats=BEATS):
    """Which wing kinds run into the legendary star (worn at full size) in some phase."""
    star = piece_tree(geometry_by_name, "star", *points["Star"])
    hit = set()
    for kind in wingkit.WINGS:
        for beat in beats:
            for side in (-1, 1):
                hinge, span = points["Wing" + ("L" if side < 0 else "R")]
                if wing_tree(geometry_by_name, kind, side, hinge, span, beat)[1].overlap(star):
                    hit.add(kind)
    return hit


def fit(info, objects, geometry_by_name, log=None):
    """The outfit's points for this body (dress.anchors), with the wings' hinges on the body's own
    surface, pushed out or the pair made smaller until no wing kind has a fault, and the star moved
    back (or made smaller) clear of every wing."""
    points = dress.anchors(info)
    body = Body(objects)
    centre = Vector(info["hull"][0])
    r = info["radius"]
    quick = BEATS
    hull_points = {s: points["Wing" + s] for s in ("L", "R")}

    def surface_hinges(lower):
        """The hinges `lower` radii down the back from the hull's points, put on the body's own
        surface straight out from the hull's centre (the hull is an ellipsoid round the body; tall
        or plated bodies stand out of it, and a hinge on it sank)."""
        hinges = {}
        for s, (hinge, span) in hull_points.items():
            start = Vector(hinge) - Vector((0, 0, lower * r))
            direction = (start - centre).normalized()
            reach = (start - centre).length * 1.6 + r
            surface = body.outermost(centre, direction, reach)
            at = (surface - direction * INSET) if surface is not None else start
            hinges[s] = (at, direction, span)
        return hinges

    def place(hinges, push, shrink):
        for s, (at, direction, span) in hinges.items():
            points["Wing" + s] = (tuple(at + direction * push * r), span * shrink)

    def first_clear(hinges):
        """The least push, then the least shrink, that leaves no fault: (push, shrink, faults left)."""
        push, shrink = 0.0, 1.0
        while True:
            place(hinges, push, shrink)
            faults = wing_faults(points, body, geometry_by_name, quick)[0]
            if not faults:
                return push, shrink, 0
            if push + PUSH_STEP <= PUSH_LIMIT + 1e-6:
                push += PUSH_STEP
            elif shrink * SHRINK_STEP >= SHRINK_LIMIT - 1e-6:
                shrink *= SHRINK_STEP
            else:
                return push, shrink, len(faults)

    # Down the back step by step: the first height where the wings fit at full size wins; else the
    # height where they stay biggest (then fewest faults).
    best = None
    for lower in LOWER_STEPS:
        hinges = surface_hinges(lower)
        push, shrink, left = first_clear(hinges)
        score = (left > 0, -shrink if left == 0 else left, push)
        if best is None or score < best[0]:
            best = (score, lower, hinges, push, shrink, left)
        if left == 0 and shrink == 1.0:
            break
    _, lower, hinges, push, shrink, left = best
    place(hinges, push, shrink)

    # The star: back from its place until no wing touches it, then smaller if that is not enough.
    star_at, star_scale = points["Star"]
    star_push, star_shrink = 0.0, 1.0
    while star_faults(points, geometry_by_name, quick):
        if star_push + PUSH_STEP <= STAR_PUSH_LIMIT + 1e-6:
            star_push += PUSH_STEP
        elif star_shrink * SHRINK_STEP >= STAR_SHRINK_LIMIT - 1e-6:
            star_shrink *= SHRINK_STEP
        else:
            break
        points["Star"] = ((star_at[0], star_at[1] + star_push * r, star_at[2]), star_scale * star_shrink)

    if log is not None:
        log(f"lower {lower:.1f} r, push {push:.2f} r, wings x{shrink:.2f}, faults left {left}, star back {star_push:.2f} r x{star_shrink:.2f}")
    return points
