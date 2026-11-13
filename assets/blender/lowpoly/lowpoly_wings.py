# The low-poly pets' wings (decision 118): five kinds, each a few faceted parts in the tones of the
# tier's colour, so a pet's wings tell its tier by colour and its roll by shape:
#   butterfly - a forewing and a hindwing, a dark border and veins, glowing eye spots;
#   angel     - three rows of feathers (coverts, secondaries, primaries) on a wing bone;
#   dragon    - a bone arm and four finger spars with a scalloped membrane, a claw at the wrist;
#   crystal   - a fan of hexagonal crystals, each with a glowing core;
#   sail      - a solar sail: a boom, dark panels in a glowing frame, a beacon at the tip.
# A wing lies in its own XZ plane: the root at the origin, reaching out along +X and up along +Z
# about one unit, thin along Y. The kit turns it into its rest pose; the game scales it to the
# body's wing span.

import math

import bmesh
from mathutils import Matrix, Vector

D = math.radians


# --- Flat shapes -----------------------------------------------------------------------------------


def _centre(points):
    return (sum(x for x, _ in points) / len(points), sum(z for _, z in points) / len(points))


def _slab(bm, outline, depth, lift=0.0, centre=None):
    """A flat outline with thickness; with `lift`, a low pyramid on both faces (a fan of facets
    from `centre`, every other rim point raised), so it catches light like a cut gem."""
    cx, cz = centre or _centre(outline)
    front = [bm.verts.new((x, -depth, z)) for x, z in outline]
    back = [bm.verts.new((x, depth, z)) for x, z in outline]
    apex_front = bm.verts.new((cx, -depth - lift, cz))
    apex_back = bm.verts.new((cx, depth + lift, cz))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((apex_front, front[j], front[i]))
        bm.faces.new((apex_back, back[i], back[j]))
        bm.faces.new((front[i], front[j], back[j], back[i]))


def _band(bm, outline, width, depth):
    """A flat band along a closed outline, `width` wide inwards (towards the outline's centre)."""
    cx, cz = _centre(outline)
    inner = []
    for x, z in outline:
        dx, dz = cx - x, cz - z
        length = math.hypot(dx, dz) or 1.0
        inner.append((x + dx / length * width, z + dz / length * width))
    n = len(outline)
    layers = []
    for y in (-depth, depth):
        layers.append(([bm.verts.new((x, y, z)) for x, z in outline], [bm.verts.new((x, y, z)) for x, z in inner]))
    (of, inf), (ob, inb) = layers
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((of[i], of[j], inf[j], inf[i]))
        bm.faces.new((ob[i], inb[i], inb[j], ob[j]))
        bm.faces.new((of[i], ob[i], ob[j], of[j]))
        bm.faces.new((inf[i], inf[j], inb[j], inb[i]))


def _strip(bm, points, width, depth, taper=0.35):
    """A flat tapering strip along an open line (a vein, a bone, a frame bar)."""
    n = len(points)
    rails = []
    for i, (x, z) in enumerate(points):
        a = Vector(points[max(i - 1, 0)])
        b = Vector(points[min(i + 1, n - 1)])
        d = (b - a).normalized()
        normal = Vector((-d.y, d.x))
        w = width * (1.0 - taper * i / max(n - 1, 1)) / 2
        rails.append(((x + normal.x * w, z + normal.y * w), (x - normal.x * w, z - normal.y * w)))
    verts = []
    for left, right in rails:
        verts.append([bm.verts.new((p[0], y, p[1])) for p in (left, right) for y in (-depth, depth)])
    for i in range(n - 1):
        (la, lb, ra, rb), (la2, lb2, ra2, rb2) = verts[i], verts[i + 1]
        bm.faces.new((la, la2, ra2, ra))
        bm.faces.new((lb, rb, rb2, lb2))
        bm.faces.new((la, lb, lb2, la2))
        bm.faces.new((ra, ra2, rb2, rb))
    first, last = verts[0], verts[-1]
    bm.faces.new((first[0], first[2], first[3], first[1]))
    bm.faces.new((last[0], last[1], last[3], last[2]))


def _gem(bm, at, radius, depth, sides=6):
    """A flat hexagonal stud with a pointed face (an eye spot, a jewel)."""
    x0, z0 = at
    rim = [(x0 + math.cos(i / sides * math.tau) * radius, z0 + math.sin(i / sides * math.tau) * radius) for i in range(sides)]
    _slab(bm, rim, depth, depth * 1.5, at)


def _crystal(bm, root, angle, length, radius):
    """A hexagonal crystal from `root` along `angle` (degrees from +X towards +Z): a prism and a
    pointed tip."""
    direction = Vector((math.cos(D(angle)), 0, math.sin(D(angle))))
    side = Vector((-direction.z, 0, direction.x))
    base = Vector((root[0], 0, root[1]))
    rings = []
    for t, scale in ((0.0, 0.7), (0.72, 1.0)):
        centre = base + direction * length * t
        ring = []
        for i in range(6):
            a = i / 6 * math.tau
            offset = side * math.cos(a) * radius * scale + Vector((0, 1, 0)) * math.sin(a) * radius * 0.55 * scale
            ring.append(bm.verts.new(tuple(centre + offset)))
        rings.append(ring)
    tip = bm.verts.new(tuple(base + direction * length))
    foot = bm.verts.new(tuple(base - direction * radius * 0.3))
    low, high = rings
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new((low[i], low[j], high[j], high[i]))
        bm.faces.new((high[i], high[j], tip))
        bm.faces.new((low[j], low[i], foot))


def _box(bm, centre, size, angle=0.0):
    """A thin box in the wing's plane, turned `angle` degrees about Y."""
    rotation = Matrix.Rotation(D(-angle), 4, "Y")
    result = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=result["verts"])
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(centre)) @ rotation, verts=result["verts"])


def _both(first, second):
    """Two fills as one (parts of one paint join into one mesh anyway)."""
    return lambda bm: (first(bm), second(bm))


def _finish(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces:
        face.smooth = False


# --- The wings: name -> [(part, paint key, fill)] ---------------------------------------------------

# The membrane is a thin flat sheet (a faint tint, AlienDress.colorWings); the lines over it glow.
# Thin, as the first wings' were: wide neon bands and veins burnt a legendary's gold wings to a white
# blot under Bloom, ten times the glowing area of the wings before the low-poly pets (user,
# 2026-11-13). LINE is an edge's width, VEIN a vein's, LINE_DEPTH how far both stand out of the
# sheet (just over it, so they show from both sides); widths in wing units (the span is 1).
DEPTH = 0.006
LINE = 0.016
VEIN = 0.009
LINE_DEPTH = 0.009

# A swallowtail: a broad forewing with a pointed apex and a slightly hollow outer edge, a hindwing
# with a tail.
BUTTERFLY_FORE = [(0.0, 0.05), (0.18, 0.42), (0.42, 0.76), (0.7, 0.98), (1.0, 1.06), (0.96, 0.84), (0.9, 0.62), (0.86, 0.42),
                  (0.62, 0.2), (0.3, 0.04)]
BUTTERFLY_HIND = [(0.0, -0.02), (0.3, -0.02), (0.58, -0.12), (0.72, -0.32), (0.66, -0.52), (0.6, -0.92), (0.48, -0.62),
                  (0.3, -0.56), (0.12, -0.4), (0.02, -0.18)]


def butterfly():
    def wings(bm):
        _slab(bm, BUTTERFLY_FORE, DEPTH, 0.0, (0.5, 0.5))
        _slab(bm, BUTTERFLY_HIND, DEPTH, 0.0, (0.36, -0.32))
        _finish(bm)

    def frame(bm):
        _band(bm, BUTTERFLY_FORE, LINE, LINE_DEPTH)
        _band(bm, BUTTERFLY_HIND, LINE, LINE_DEPTH)
        for tip in ((0.66, 0.9), (0.86, 0.5)):
            _strip(bm, [(0.02, 0.06), (tip[0] * 0.5, tip[1] * 0.5 + 0.03), tip], VEIN, LINE_DEPTH)
        for tip in ((0.52, -0.58),):
            _strip(bm, [(0.02, -0.03), (tip[0] * 0.5, tip[1] * 0.5), tip], VEIN, LINE_DEPTH)
        _finish(bm)

    def spots(bm):
        _gem(bm, (0.66, 0.66), 0.04, LINE_DEPTH)
        _gem(bm, (0.44, -0.36), 0.035, LINE_DEPTH)
        _gem(bm, (0.86, 0.9), 0.025, LINE_DEPTH)
        _finish(bm)

    return [("wings", "wing", wings), ("frame", "wingEdge", _both(frame, spots))]


def _feather(bm, root, angle, length, width):
    """One feather: a long leaf with a ridge, from `root` along `angle`."""
    d = Vector((math.cos(D(angle)), math.sin(D(angle))))
    n = Vector((-d.y, d.x))
    r = Vector(root)
    outline = [tuple(r + n * width * 0.25), tuple(r + d * length * 0.35 + n * width * 0.5), tuple(r + d * length * 0.8 + n * width * 0.42),
               tuple(r + d * length), tuple(r + d * length * 0.8 - n * width * 0.42), tuple(r + d * length * 0.35 - n * width * 0.5),
               tuple(r - n * width * 0.25)]
    _slab(bm, outline, DEPTH, 0.0, tuple(r + d * length * 0.5))


def angel():
    # The bone runs from the root up and out to the wrist; feathers hang from it, longest at the tip.
    bone = [(0.0, 0.05), (0.38, 0.5), (0.78, 0.82)]

    def along(t):
        if t < 0.5:
            a, b, s = bone[0], bone[1], t / 0.5
        else:
            a, b, s = bone[1], bone[2], (t - 0.5) / 0.5
        return (a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s)

    # (root along the bone, angle, length, width): primaries at the tip, secondaries under the arm,
    # short coverts over both.
    rows = [(min(0.55 + i * 0.09, 1.0), -60 + i * 14, 0.62 + 0.1 * i, 0.16) for i in range(6)]
    rows += [(0.12 + i * 0.1, -98 + i * 6, 0.5 + 0.04 * i, 0.17) for i in range(5)]
    coverts = [(0.08 + i * 0.15, -75 + i * 10, 0.3, 0.16) for i in range(6)]

    def feathers(bm):
        for t, angle, length, width in rows + coverts:
            _feather(bm, along(t), angle, length, width)
        _finish(bm)

    def shafts(bm):
        # A glowing shaft down each long feather and the bone, raised over the facets.
        _strip(bm, bone, LINE * 1.2, LINE_DEPTH, 0.2)
        for t, angle, length, _ in rows:
            root = Vector(along(t))
            d = Vector((math.cos(D(angle)), math.sin(D(angle))))
            _strip(bm, [tuple(root), tuple(root + d * length * 0.5), tuple(root + d * length * 0.92)], VEIN * 0.8, LINE_DEPTH, 0.6)
        for t in (0.3, 0.62, 0.95):
            _gem(bm, along(t), 0.022, LINE_DEPTH)
        _finish(bm)

    return [("feathers", "wing", feathers), ("shafts", "wingEdge", shafts)]


def _fairy_outline():
    """The fairy wing's key points as they are (robo.WING_OUTLINE, root first): the faceted outline."""
    import robo

    return list(robo.WING_OUTLINE)


def fairy():
    """The fairy wings as the first low-poly version drew them (lowpoly_kit's faceted `wing` and
    `wing_edge`, commit 3aff207): the user's reference outline (robo.py, decision 074) cut from its
    key points, a faceted membrane fanning from the root and a glowing band along the edge. The
    user wants this one, not the pre-low-poly look with veins and cells (2026-11-13)."""
    import lowpoly_kit

    outline = _fairy_outline()

    def membrane(bm):
        lowpoly_kit._prism(bm, outline, DEPTH, 0.0)
        _finish(bm)

    def edge(bm):
        lowpoly_kit._frame(bm, outline, 0.975, LINE_DEPTH)
        _finish(bm)

    return [("membrane", "wing", membrane), ("lines", "wingEdge", edge)]


def fairy_dust():
    """Where the fairy wing's stroke runs as it beats: its own outline (the one `fairy` draws) from
    the forewing's tip down the outer edge (robo.WING_DUST_TRACE's first five points, snapped to
    the outline). The trace itself sat off this outline and jumped to the hind lobe, so the stroke
    missed the edge (user, 2026-11-13)."""
    import robo

    outline = _fairy_outline()
    trace = robo._from_trace(robo.WING_DUST_TRACE)

    def nearest(point):
        return min(range(len(outline)), key=lambda i: (outline[i][0] - point[0]) ** 2 + (outline[i][1] - point[1]) ** 2)

    start, end = nearest(trace[0]), nearest(trace[4])
    if start <= end:
        return outline[start:end + 1]
    return outline[start:] + outline[:end + 1]


def dragon():
    wrist = (0.42, 0.62)
    tips = [(1.05, 0.86), (1.08, 0.38), (0.92, -0.02), (0.62, -0.3)]

    def bones(bm):
        _strip(bm, [(0.0, 0.05), (0.2, 0.38), wrist], LINE * 1.5, LINE_DEPTH, 0.3)
        for tip in tips:
            mid = ((wrist[0] + tip[0]) / 2 + 0.03, (wrist[1] + tip[1]) / 2 + 0.03)
            _strip(bm, [wrist, mid, tip], LINE, LINE_DEPTH, 0.7)
        _finish(bm)

    def membrane(bm):
        # Between the root, the wrist and each fingertip, the trailing edge bowed in between tips.
        outline = [(0.0, 0.02), (0.18, 0.38), wrist, tips[0]]
        for a, b in zip(tips, tips[1:]):
            outline.append(((a[0] + b[0]) / 2 - 0.12, (a[1] + b[1]) / 2 - 0.02))
            outline.append(b)
        outline.append((0.24, -0.18))
        _slab(bm, outline, DEPTH, 0.0, (0.5, 0.35))
        _finish(bm)

    def claws(bm):
        cx, cz = wrist
        outline = [(cx - 0.04, cz), (cx + 0.02, cz + 0.2), (cx + 0.06, cz)]
        _slab(bm, outline, DEPTH * 2, DEPTH * 2, (cx + 0.01, cz + 0.06))
        for tip in tips:
            x, z = tip
            _gem(bm, (x, z), 0.02, LINE_DEPTH, 4)
        _finish(bm)

    return [("membrane", "wing", membrane), ("bones", "wingEdge", _both(bones, claws))]


# The crystal fan: (angle from the side, up; length; radius). Every crystal leans out: one past the
# vertical (100 degrees, once) leant over the body and crossed the other wing's (user, 2026-11-13).
CRYSTAL_SHARDS = [(14, 0.62, 0.075), (34, 0.95, 0.085), (52, 1.12, 0.09), (68, 0.85, 0.075), (80, 0.55, 0.06)]


def crystal():
    shards = CRYSTAL_SHARDS

    def shell(bm):
        for angle, length, radius in shards:
            _crystal(bm, (0.04, 0.04), angle, length, radius)
        _finish(bm)

    def cores(bm):
        for angle, length, radius in shards:
            _crystal(bm, (0.06, 0.06), angle, length * 0.72, radius * 0.2)
        _finish(bm)

    def foot(bm):
        _gem(bm, (0.02, 0.02), 0.05, LINE_DEPTH)
        _finish(bm)

    return [("shell", "wing", shell), ("cores", "wingEdge", _both(cores, foot))]


# The order is the pools' (Domain/AlienOutfit): add new kinds at the end.
WINGS = {"butterfly": butterfly, "angel": angel, "dragon": dragon, "crystal": crystal, "fairy": fairy}


def _angel_tips():
    bone = [(0.0, 0.05), (0.38, 0.5), (0.78, 0.82)]
    tips = []
    for i in range(6):
        t = min(0.55 + i * 0.09, 1.0)
        a, b, s = (bone[0], bone[1], t / 0.5) if t < 0.5 else (bone[1], bone[2], (t - 0.5) / 0.5)
        root = (a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s)
        angle, length = D(-60 + i * 14), 0.62 + 0.1 * i
        tips.append((root[0] + math.cos(angle) * length, root[1] + math.sin(angle) * length))
    return list(reversed(tips))


def dust(kind):
    """Points along a wing's outer edge, from its tip down: the game strings a glowing stroke through
    them that trails the wing as it beats (AlienDress, `wings`; the user likes it, 2026-11-13)."""
    if kind == "fairy":
        return fairy_dust()
    if kind == "butterfly":
        # The forewing's own outline from the leading edge round the apex and down the outer edge: a
        # stroke from one wing to the other cut across the gap, off the contour (user, 2026-11-13).
        return BUTTERFLY_FORE[3:9]
    if kind == "angel":
        return _angel_tips()
    if kind == "dragon":
        return [(1.05, 0.86), (1.08, 0.38), (0.92, -0.02), (0.62, -0.3)]
    if kind == "crystal":
        shards = sorted(CRYSTAL_SHARDS[:3], key=lambda shard: -shard[0])
        return [(0.04 + math.cos(D(a)) * length, 0.04 + math.sin(D(a)) * length) for a, length, _ in shards]
    return []
