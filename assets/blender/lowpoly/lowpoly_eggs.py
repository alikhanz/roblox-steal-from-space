# The space egg in the faceted low-poly style (decision 122): "Самоцвет", the egg as a cut gem
# (concept docs/design/concepts/lowpoly-eggs/, the user's pick of three). Every egg wears the same
# shell and girdle; its rarity adds a point, fins, an orbit and a gold crown; a meteor egg adds
# lava cracks and a flame, the star egg a gold star on top and star specks. One mesh per shape,
# shared by every egg: the game colours each part (World/EggModel, Config/EggLooks), nothing is
# baked.
#
# Shapes about the egg's centre (the origin) at a medium egg's size (EggLooks.EGG_SIZE: 1.6 x 2.1 x
# 1.6 studs), its front -Y (the look vector, -Z, in Roblox). Each `fill_*` writes one shape into a
# bmesh; `SHAPES` maps the game's piece names to them. Used by export_eggs_lowpoly.py (the egg kit)
# and export_serpent_lowpoly.py (the star egg in the serpent's cradle).

import math

from mathutils import Matrix, Vector

# A medium egg: half its width and height, studs.
HALF_W, HALF_H = 0.8, 1.05
# How much narrower the top is than the bottom.
TAPER = 0.12


def radius_at(z, taper=TAPER):
    """The egg's profile: its radius at height z (-HALF_H..HALF_H), narrower at the top."""
    t = max(-1.0, min(1.0, z / HALF_H))
    return HALF_W * math.sqrt(max(0.0, 1 - t * t)) * (1 - taper * t)


def on_shell(angle, z, out=0.0):
    r = radius_at(z) + out
    return Vector((math.cos(angle) * r, math.sin(angle) * r, z))


def normal_at(angle, z):
    return Vector((math.cos(angle), math.sin(angle), 0.35 * z / HALF_H)).normalized()


def lathe(bm, sides, rings, twist=0.0):
    """A closed faceted egg: `rings` rows of `sides` points, every other row turned by `twist` of a
    step (triangle facets, like a cut gem)."""
    levels = []
    for i in range(1, rings + 1):
        z = -HALF_H + 2 * HALF_H * i / (rings + 1)
        r = radius_at(z)
        ring = []
        for k in range(sides):
            a = (k + (twist if i % 2 else 0.0)) / sides * math.tau
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        levels.append(ring)
    bottom = bm.verts.new((0, 0, -HALF_H))
    top = bm.verts.new((0, 0, HALF_H))
    for k in range(sides):
        j = (k + 1) % sides
        bm.faces.new((bottom, levels[0][j], levels[0][k]))
        bm.faces.new((top, levels[-1][k], levels[-1][j]))
    for a, b in zip(levels, levels[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((a[k], a[j], b[j]))
            bm.faces.new((a[k], b[j], b[k]))


def band(bm, z0, z1, sides, out, twist=0.0):
    """A closed ring band on the egg's surface from z0 to z1, `out` proud of it."""
    def ring(z, r):
        return [bm.verts.new((math.cos((k + twist) / sides * math.tau) * r, math.sin((k + twist) / sides * math.tau) * r, z)) for k in range(sides)]
    outer = [ring(z, radius_at(z) + out) for z in (z0, z1)]
    inner = [ring(z, radius_at(z) - 0.01) for z in (z0, z1)]
    for k in range(sides):
        j = (k + 1) % sides
        bm.faces.new((outer[0][k], outer[0][j], outer[1][j], outer[1][k]))
        bm.faces.new((inner[0][k], inner[1][k], inner[1][j], inner[0][j]))
        bm.faces.new((outer[0][k], inner[0][k], inner[0][j], outer[0][j]))
        bm.faces.new((outer[1][k], outer[1][j], inner[1][j], inner[1][k]))


def cone(bm, base, tip, radius, sides=4, turn=0.0):
    base, tip = Vector(base), Vector(tip)
    axis = (tip - base).normalized()
    side = axis.orthogonal().normalized()
    other = axis.cross(side)
    ring = []
    for k in range(sides):
        a = (k + turn) / sides * math.tau
        ring.append(bm.verts.new(base + (side * math.cos(a) + other * math.sin(a)) * radius))
    apex = bm.verts.new(tip)
    for k in range(sides):
        bm.faces.new((ring[k], ring[(k + 1) % sides], apex))
    bm.faces.new(list(reversed(ring)))


def torus(bm, major, minor, segments, sides, tilt):
    m = Matrix.Rotation(tilt[0], 4, "X") @ Matrix.Rotation(tilt[1], 4, "Y")
    rings = []
    for i in range(segments):
        a = i / segments * math.tau
        centre = Vector((math.cos(a) * major, math.sin(a) * major, 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        ring = []
        for k in range(sides):
            b = k / sides * math.tau
            ring.append(bm.verts.new(m @ (centre + out * math.cos(b) * minor + Vector((0, 0, math.sin(b) * minor)))))
        rings.append(ring)
    for i in range(segments):
        a, b = rings[i], rings[(i + 1) % segments]
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((a[k], b[k], b[j], a[j]))


def star_prism(bm, centre, radius, depth, normal, points=5, inner=0.45):
    """A flat star standing out of the surface along `normal`, its point raised."""
    n = Vector(normal).normalized()
    up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    u = up - n * up.dot(n)
    u.normalize()
    v = n.cross(u)
    c = Vector(centre)
    outline = []
    for i in range(points * 2):
        a = i / (points * 2) * math.tau + math.pi / 2
        r = radius if i % 2 == 0 else radius * inner
        outline.append(u * math.cos(a) * r + v * math.sin(a) * r)
    front = [bm.verts.new(c + p + n * depth) for p in outline]
    back = [bm.verts.new(c + p - n * 0.01) for p in outline]
    apex = bm.verts.new(c + n * depth * 1.6)
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((front[i], front[j], apex))
        bm.faces.new((back[i], front[i], front[j], back[j]))


def strip(bm, points, width, out):
    """A flat strip along a polyline on the egg (a crack), standing `out` off the surface."""
    pts = [on_shell(a, z, out) for a, z in points]
    rails = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        n = Vector((p.x, p.y, 0)).normalized()
        side = d.cross(n).normalized() * width / 2
        rails.append((bm.verts.new(p + side), bm.verts.new(p - side)))
    for (a, b), (c, d) in zip(rails, rails[1:]):
        bm.faces.new((a, b, d, c))


# --- The shapes, by the game's piece names (World/EggModel) -------------------------------------


def fill_shell(bm):
    lathe(bm, 8, 5, 0.5)


def fill_girdle(bm):
    band(bm, -0.18, -0.06, 8, 0.03, twist=0.5)


def fill_tip(bm):
    cone(bm, (0, 0, HALF_H - 0.08), (0, 0, HALF_H + 0.32), 0.14, 4)


def fill_fins(bm):
    for a in (0, math.pi):
        base = on_shell(a, -0.1, -0.05)
        cone(bm, base, base + Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.25)), 0.12, 3)


def fill_orbit(bm):
    torus(bm, 1.15, 0.045, 14, 3, (math.radians(70), math.radians(18)))


def fill_crown(bm):
    for k in range(5):
        a = k / 5 * math.tau
        base = on_shell(a, 0.55, -0.04)
        cone(bm, base, base + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.62)), 0.13, 3)


def fill_meteor_cracks(bm):
    for a0 in (-1.6, -0.4, 1.2, 2.6):
        strip(bm, [(a0, 0.95), (a0 + 0.2, 0.55), (a0 - 0.15, 0.2), (a0 + 0.12, -0.2), (a0 - 0.1, -0.55)], 0.06, 0.05)


def fill_meteor_flame(bm):
    cone(bm, (0, 0, HALF_H - 0.12), (0, 0, HALF_H + 0.5), 0.2, 5)


def fill_star_top(bm):
    star_prism(bm, (0, 0, HALF_H + 0.34), 0.36, 0.06, (0, -1, 0))


def fill_star_dots(bm):
    for a, z, r in ((-1.2, 0.35, 0.14), (-2.1, -0.3, 0.12), (-0.5, -0.45, 0.1), (0.9, 0.25, 0.12), (2.6, -0.1, 0.12)):
        star_prism(bm, on_shell(a, z), r, 0.03, normal_at(a, z))


SHAPES = {
    "GemShell": fill_shell,
    "GemGirdle": fill_girdle,
    "GemTip": fill_tip,
    "GemFins": fill_fins,
    "GemOrbit": fill_orbit,
    "GemCrown": fill_crown,
    "MeteorCracks": fill_meteor_cracks,
    "MeteorFlame": fill_meteor_flame,
    "StarTop": fill_star_top,
    "StarDots": fill_star_dots,
}
