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


def _finish(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces:
        face.smooth = False


# --- The wings: name -> [(part, paint key, fill)] ---------------------------------------------------

DEPTH = 0.016

# A swallowtail: a broad forewing with a pointed apex and a slightly hollow outer edge, a hindwing
# with a tail.
BUTTERFLY_FORE = [(0.0, 0.05), (0.18, 0.42), (0.42, 0.76), (0.7, 0.98), (1.0, 1.06), (0.96, 0.84), (0.9, 0.62), (0.86, 0.42),
                  (0.62, 0.2), (0.3, 0.04)]
BUTTERFLY_HIND = [(0.0, -0.02), (0.3, -0.02), (0.58, -0.12), (0.72, -0.32), (0.66, -0.52), (0.6, -0.92), (0.48, -0.62),
                  (0.3, -0.56), (0.12, -0.4), (0.02, -0.18)]


def butterfly():
    def wings(bm):
        _slab(bm, BUTTERFLY_FORE, DEPTH, 0.02, (0.5, 0.5))
        _slab(bm, BUTTERFLY_HIND, DEPTH, 0.018, (0.36, -0.32))
        _finish(bm)

    def frame(bm):
        # Raised over the facets (their apex stands DEPTH + lift out), so the border and veins show.
        _band(bm, BUTTERFLY_FORE, 0.11, 0.04)
        _band(bm, BUTTERFLY_HIND, 0.09, 0.036)
        for tip in ((0.66, 0.9), (0.9, 0.7), (0.8, 0.4)):
            _strip(bm, [(0.02, 0.06), (tip[0] * 0.5, tip[1] * 0.5 + 0.03), tip], 0.035, 0.038)
        for tip in ((0.6, -0.55), (0.32, -0.5)):
            _strip(bm, [(0.02, -0.03), (tip[0] * 0.5, tip[1] * 0.5), tip], 0.03, 0.034)
        _finish(bm)

    def spots(bm):
        _gem(bm, (0.66, 0.66), 0.1, 0.045)
        _gem(bm, (0.44, -0.36), 0.08, 0.042)
        _gem(bm, (0.86, 0.9), 0.05, 0.045)
        _finish(bm)

    return [("wings", "tierBody", wings), ("frame", "tierDeep", frame), ("spots", "tier", spots)]


def _feather(bm, root, angle, length, width):
    """One feather: a long leaf with a ridge, from `root` along `angle`."""
    d = Vector((math.cos(D(angle)), math.sin(D(angle))))
    n = Vector((-d.y, d.x))
    r = Vector(root)
    outline = [tuple(r + n * width * 0.25), tuple(r + d * length * 0.35 + n * width * 0.5), tuple(r + d * length * 0.8 + n * width * 0.42),
               tuple(r + d * length), tuple(r + d * length * 0.8 - n * width * 0.42), tuple(r + d * length * 0.35 - n * width * 0.5),
               tuple(r - n * width * 0.25)]
    _slab(bm, outline, DEPTH, 0.025, tuple(r + d * length * 0.5))


def angel():
    # The bone runs from the root up and out to the wrist; feathers hang from it, longest at the tip.
    bone = [(0.0, 0.05), (0.38, 0.5), (0.78, 0.82)]

    def along(t):
        if t < 0.5:
            a, b, s = bone[0], bone[1], t / 0.5
        else:
            a, b, s = bone[1], bone[2], (t - 0.5) / 0.5
        return (a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s)

    def primaries(bm):
        for i in range(6):
            t = 0.55 + i * 0.09
            _feather(bm, along(min(t, 1.0)), -60 + i * 14, 0.62 + 0.1 * i, 0.16)
        _finish(bm)

    def secondaries(bm):
        for i in range(5):
            _feather(bm, along(0.12 + i * 0.1), -98 + i * 6, 0.5 + 0.04 * i, 0.17)
        _finish(bm)

    def coverts(bm):
        for i in range(6):
            _feather(bm, along(0.08 + i * 0.15), -75 + i * 10, 0.3, 0.16)
        _strip(bm, bone, 0.09, DEPTH * 2.2, 0.2)
        _finish(bm)

    def gems(bm):
        for t in (0.3, 0.62, 0.95):
            _gem(bm, along(t), 0.05, DEPTH * 3)
        _finish(bm)

    return [("primaries", "tierDeep", primaries), ("secondaries", "tierBody", secondaries), ("coverts", "tierLight", coverts),
            ("gems", "tier", gems)]


def dragon():
    wrist = (0.42, 0.62)
    tips = [(1.05, 0.86), (1.08, 0.38), (0.92, -0.02), (0.62, -0.3)]

    def bones(bm):
        _strip(bm, [(0.0, 0.05), (0.2, 0.38), wrist], 0.1, DEPTH * 2.4, 0.3)
        for tip in tips:
            mid = ((wrist[0] + tip[0]) / 2 + 0.03, (wrist[1] + tip[1]) / 2 + 0.03)
            _strip(bm, [wrist, mid, tip], 0.06, DEPTH * 2, 0.7)
        _finish(bm)

    def membrane(bm):
        # Between the root, the wrist and each fingertip, the trailing edge bowed in between tips.
        outline = [(0.0, 0.02), (0.18, 0.38), wrist, tips[0]]
        for a, b in zip(tips, tips[1:]):
            outline.append(((a[0] + b[0]) / 2 - 0.12, (a[1] + b[1]) / 2 - 0.02))
            outline.append(b)
        outline.append((0.24, -0.18))
        _slab(bm, outline, DEPTH, 0.03, (0.5, 0.35))
        _finish(bm)

    def claws(bm):
        cx, cz = wrist
        outline = [(cx - 0.04, cz), (cx + 0.02, cz + 0.2), (cx + 0.06, cz)]
        _slab(bm, outline, DEPTH * 2, DEPTH * 2, (cx + 0.01, cz + 0.06))
        for tip in tips:
            x, z = tip
            _gem(bm, (x, z), 0.035, DEPTH * 2.5, 4)
        _finish(bm)

    return [("membrane", "tierBody", membrane), ("bones", "tierDeep", bones), ("claws", "tier", claws)]


def crystal():
    shards = [(20, 0.62, 0.075), (42, 0.95, 0.085), (62, 1.12, 0.09), (82, 0.8, 0.075), (100, 0.5, 0.06)]

    def shell(bm):
        for angle, length, radius in shards:
            _crystal(bm, (0.04, 0.04), angle, length, radius)
        _finish(bm)

    def cores(bm):
        for angle, length, radius in shards:
            _crystal(bm, (0.06, 0.06), angle, length * 0.72, radius * 0.45)
        _finish(bm)

    def foot(bm):
        _gem(bm, (0.02, 0.02), 0.12, DEPTH * 3)
        _finish(bm)

    return [("shell", "tierGlass", shell), ("cores", "tier", cores), ("foot", "tierDeep", foot)]


def sail():
    def boom(bm):
        _strip(bm, [(0.0, 0.08), (0.5, 0.5), (1.02, 0.92)], 0.05, DEPTH * 2.5, 0.2)
        for t in (0.35, 0.68):
            x, z = 0.02 + t, 0.1 + t * 0.82
            _strip(bm, [(x, z), (x + 0.3, z - 0.42)], 0.03, DEPTH * 2, 0.0)
        _finish(bm)

    panels_at = [((0.42, 0.3), (0.26, 0.4), -38), ((0.75, 0.58), (0.26, 0.42), -38), ((1.02, 0.8), (0.18, 0.28), -38)]

    def panels(bm):
        for (x, z), (w, h), angle in panels_at:
            _box(bm, (x, 0, z), (w, DEPTH * 1.6, h), angle)
        _finish(bm)

    def grid(bm):
        for (x, z), (w, h), angle in panels_at:
            a = D(-angle)
            # The panel's frame: a band round it, and a bar across.
            corners = []
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                px, pz = sx * w / 2, sz * h / 2
                corners.append((x + px * math.cos(a) + pz * math.sin(a), z - px * math.sin(a) + pz * math.cos(a)))
            _band(bm, corners, 0.025, DEPTH * 2.1)
            left = ((corners[0][0] + corners[3][0]) / 2, (corners[0][1] + corners[3][1]) / 2)
            right = ((corners[1][0] + corners[2][0]) / 2, (corners[1][1] + corners[2][1]) / 2)
            _strip(bm, [left, right], 0.02, DEPTH * 2.1, 0.0)
        _gem(bm, (1.06, 0.96), 0.06, DEPTH * 3)
        _finish(bm)

    return [("boom", "engine", boom), ("panels", "panel", panels), ("grid", "tier", grid)]


WINGS = {"butterfly": butterfly, "angel": angel, "dragon": dragon, "crystal": crystal, "sail": sail}
