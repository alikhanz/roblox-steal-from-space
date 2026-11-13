# Concept (low-poly pets): three families (slime, crab, whale), three signatures (siren, rotor,
# galaxy) and the tier outfit, built from the shared kit (lowpoly_kit.py) in any of its styles.
#
# A kind keeps its colours, its silhouette parameters and its signature from robo_kinds.py; only the
# geometry changes. Every part is a placement of a library mesh: the body of a kind is the same
# meshes in all ten variants (the tier changes paint and adds outfit pieces; a legendary's gold is
# a material, not a mesh), and the outfit (antenna, jetpack, wings, crown, star, tier ring) is one
# set of meshes for every kind of the game.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))
sys.path.insert(0, HERE)

import lowpoly_kit as kit  # noqa: E402
import robo  # noqa: E402
import robo_kinds  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

D = math.radians
GOLD = robo.GOLD
TIER_COLORS = robo.TIER_COLORS
GROWTH = robo.GROWTH
VISOR = (0.015, 0.02, 0.03)
ENGINE = (0.09, 0.1, 0.12)
WHITE = (0.95, 0.97, 1.0)
GALAXY = (0.3, 0.18, 0.78)  # Color3.fromRGB(150, 115, 230) in linear


class Context:
    """What a builder needs: the pet being placed, the kind's paints at this tier, the style."""

    def __init__(self, pet, colours, tier, meteor, style):
        self.pet, self.colours, self.tier, self.meteor, self.style = pet, colours, tier, meteor, style
        self.face = kit.FACE[style]
        self.limb = 1.25 if style == "toy" else 1.0

    def paint(self, key):
        c = self.colours
        tier_colour = robo.FIRE if self.meteor else TIER_COLORS[self.tier]
        if key == "shell":
            if self.meteor:
                return kit.paint("plastic", (0.12, 0.03, 0.01))
            if self.tier == 4:
                return kit.paint("metal", GOLD)
            return kit.paint("candy" if c.get("paint") == "candy" else "plastic", c["shell"])
        table = {
            "trim": ("plastic", c["trim"]),
            "glow": ("neon", c["glow"]),
            "eyes": ("neon", c["eyes"]),
            "core": ("neon", c["core"]),
            "dome": ("glass", tuple(0.75 + 0.25 * v for v in c["core"])),
            "visor": ("gloss", VISOR),
            "engine": ("plastic", ENGINE),
            "white": ("neon", WHITE),
            "tier": ("neon", tier_colour),
            "armour": ("metal", GOLD) if self.tier == 4 else ("plastic", c["trim"]),
            # A rolled piece's solid part: the tier's colour (gold metal on a legendary).
            "tierBody": ("metal", GOLD) if self.tier == 4 and not self.meteor else ("plastic", tier_colour),
            "gold": ("metal", GOLD),
            "wing": ("glassglow", GOLD if self.tier == 4 and not self.meteor else tier_colour),
            "wingEdge": ("neon", GOLD if self.tier == 4 and not self.meteor else tier_colour),
            "galaxy": ("plastic", GALAXY),
            "red": ("neon", (1.0, 0.1, 0.1)),
            "blue": ("neon", (0.15, 0.35, 1.0)),
            "blade": ("plastic", (0.85, 0.87, 0.9)),
            "gemPink": ("neon", (1.0, 0.3, 0.5)),
        }
        if key in table:
            return kit.paint(*table[key])
        # Anything else: as the game will paint its code.
        letter, rest = self.code(key)[0], self.code(key)[1:].split(",")
        colour = tuple((int(v) / 255) ** 2.2 for v in rest[:3])
        kind = {"N": "neon", "G": "glass"}.get(letter, "metal" if float(rest[4]) >= 0.3 else "plastic")
        return kit.paint(kind, colour)

    def code(self, key):
        """The paint code the game reads (AlienDress, the Paint attribute):
        <S|N|G|L><r>,<g>,<b>,<transparency>,<reflectance>,<source>, colours in sRGB 0-255. Parts whose
        look depends on the tier carry a source the game recolours: Shell (gold on a legendary, lava on
        a meteor), Tier* and EnergyWing (the tier's colour), Jet (a jetpack's flame)."""
        c = self.colours
        shell = ("S", c["shell"], 0, 0.35, "Candy") if c.get("paint") == "candy" else ("S", c["shell"], 0, 0.02, "Shell")
        if c.get("finish") == "glass":
            shell = ("G", c["shell"], 0.55, 0, "Crystal")
        tier = TIER_COLORS[self.tier]
        table = {
            "shell": shell,
            "trim": ("S", c["trim"], 0, 0.02, "Trim"),
            "glow": ("N", c["glow"], 0, 0, "Seam"),
            "eyes": ("N", c["eyes"], 0, 0, "EyeLight"),
            "white": ("N", WHITE, 0, 0, "EyeShine"),
            "core": ("N", c["core"], 0, 0, "Core"),
            "jelly": ("S", c["core"], 0, 0.02, "Jelly"),
            "dome": ("G", tuple(0.75 + 0.25 * v for v in c["core"]), 0.78, 0, "Dome"),
            "visor": ("S", VISOR, 0, 0.1, "Visor"),
            "engine": ("S", ENGINE, 0, 0.05, "Engine"),
            "gold": ("S", GOLD, 0, 0.35, "Gold"),
            "badge": ("S", GOLD, 0, 0.35, "Badge"),
            "galaxy": ("S", GALAXY, 0, 0, "Galaxy"),
            "red": ("N", (1.0, 0.1, 0.1), 0, 0, "Siren"),
            "blue": ("N", (0.15, 0.35, 1.0), 0, 0, "Siren"),
            "blade": ("S", (0.85, 0.87, 0.9), 0, 0.02, "Blade"),
            "gemPink": ("N", (1.0, 0.3, 0.5), 0, 0, "Gem"),
            "snow": ("S", WHITE, 0, 0.02, "Snow"),
            "ice": ("G", (0.75, 0.95, 1.0), 0.5, 0, "IceSpike"),
            "starGold": ("N", GOLD, 0, 0, "Star"),
            "flame": ("N", (1.0, 0.55, 0.1), 0, 0, "Flame"),
            "bolt": ("N", (1.0, 0.9, 0.3), 0, 0, "Bolt"),
            "void": ("S", (0.0, 0.0, 0.0), 0, 0.1, "Void"),
            "horizon": ("N", (1.0, 0.6, 0.95), 0, 0, "Horizon"),
            "horizonOuter": ("N", (0.6, 0.5, 1.0), 0, 0, "HorizonOuter"),
            "jewel": ("N", (0.4, 0.8, 1.0), 0, 0, "Jewel"),
            "circlet": ("S", GOLD, 0, 0.35, "Circlet"),
            "dot": ("N", c["glow"], 0, 0, "Dot"),
            "backStar": ("N", (1.0, 0.95, 0.85), 0, 0, "BackStar"),
            "planet": ("S", (0.55, 0.45, 0.95), 0, 0.02, "Planet"),
            # The rolled outfit: painted in the tier's colours by the game (here tier 2's, a stand-in).
            "tierBody": ("S", tier, 0, 0.02, "TierBody"),
            "tier": ("N", tier, 0, 0, "TierGlow"),
            "tierGlass": ("G", tier, 0.5, 0, "TierGlass"),
            "wing": ("G", tier, 0.8, 0, "EnergyWing"),
            "wingEdge": ("N", tier, 0, 0, "TierGlow"),
            "jet": ("N", tier, 0, 0, "Jet"),
        }
        letter, colour, transparency, reflectance, source = table[key]
        rgb = ",".join(str(round(srgb(v) * 255)) for v in colour[:3])
        return f"{letter}{rgb},{transparency:g},{reflectance:g},{source}"

    def put(self, mesh, location, scale, key, rotation=(0, 0, 0), role="body"):
        obj = self.pet.put(mesh, location, scale, self.paint(key), rotation, role)
        obj["paint"] = self.code(key)
        return obj


def srgb(channel):
    """A linear colour channel as sRGB (what Roblox's Color3 takes)."""
    channel = max(0.0, min(1.0, channel))
    return channel * 12.92 if channel <= 0.0031308 else 1.055 * channel ** (1 / 2.4) - 0.055


# --- Surface helpers: the hull is an ellipsoid (centre, radii) ---------------------------------------


def on_hull(info, point, lift=0.0):
    """`point` moved onto the hull ellipsoid straight out from its centre, `lift` further out."""
    centre, radii = Vector(info["hull"][0]), info["hull"][1]
    offset = Vector(point) - centre
    reach = math.sqrt(sum((offset[i] / radii[i]) ** 2 for i in range(3)))
    out = offset.normalized()
    return tuple(centre + offset / reach + out * lift)


def top_height(info, x, y):
    (cx, cy, cz), (a, b, c) = info["hull"]
    inside = 1.0 - ((x - cx) / a) ** 2 - ((y - cy) / b) ** 2
    return cz + c * math.sqrt(max(inside, 0.0))


def face(ctx, centre, width, height, tilt=0.0, lens="ball"):
    """The visor: a dark lens with two eyes and their highlights. Eyes are the style's shared eye
    mesh, each its own part (each blinks in game)."""
    x, y, z = centre
    eye = ctx.face["eye"]
    turn = (D(tilt), 0, 0)
    if ctx.style == "sharp":
        # A flat hexagonal lens facing forward.
        ctx.put("can", (x, y, z), (width * 0.62, height * 1.5, 0.05), "visor", (D(90 + tilt), 0, D(30)))
    else:
        ctx.put("ball", (x, y, z), (width * 1.08, 0.09, height * 1.25 * min(eye, 1.2)), "visor", turn)
    eye_mesh = "dot" if ctx.style == "sharp" else "ball"
    for side in (-1, 1):
        ex = x + side * width * 0.45
        ctx.put(eye_mesh, (ex, y - 0.07, z + height * 0.05), (width * 0.2 * eye, 0.04, height * 0.55 * eye), "eyes", turn, "eye")
        if ctx.face["highlight"]:
            ctx.put("dot", (ex - width * 0.06 * eye, y - 0.105, z + height * 0.3 * eye), (width * 0.06 * eye, 0.02, width * 0.06 * eye), "white", turn, "eye")


# --- Families ------------------------------------------------------------------------------------------


def slime(ctx, p):
    w, h = p.get("w", 1.0), p.get("h", 1.0)
    ctx.put("can", (0, 0, 0.25), (0.75 * w, 0.75 * w, 0.2), "shell")
    ctx.put("seam", (0, 0, 0.46), (0.74 * w, 0.74 * w, 0.74 * w), "glow")
    dome_z = 0.1 + 0.9 * h
    # The jelly: two blobs in the core's colour, solid (big Neon blobs burn to white under Bloom;
    # Studio, 2026-11-13). The dome over them sets the jelly's floor.
    ctx.put("ball", (0, 0, dome_z - 0.25), (0.58 * w, 0.58 * w, 0.48 * h), "jelly")
    ctx.put("ball", (0, 0.02, dome_z + 0.22 * h), (0.36 * w, 0.36 * w, 0.32 * h), "jelly")
    ctx.put("ball_hi", (0, 0, dome_z), (0.78 * w, 0.78 * w, 0.9 * h), "dome", role="dome")
    face(ctx, (0, -0.74 * w, dome_z), 0.42 * min(w, 1.15), 0.18)
    for side in (-1, 1):
        ctx.put("block", (side * 0.55 * w, -0.15, 0.1), (0.18 * ctx.limb, 0.28, 0.1), "trim")
    if ctx.style == "sharp":
        # Pointy ears on the dome: the silhouette's accent.
        for side in (-1, 1):
            base = on_hull({"hull": ((0, 0, dome_z), (0.78 * w, 0.78 * w, 0.9 * h))}, (side * 0.5 * w, 0, dome_z + 0.7 * h), -0.06)
            ctx.put("cone", base, (0.14, 0.1, 0.4), "trim", (0, D(side * -28), 0))
    top = dome_z + 0.9 * h
    return {"hull": ((0, 0, dome_z), (0.78 * w, 0.78 * w, 0.9 * h)), "top": (0, 0, top), "center": (0, 0, dome_z - 0.1),
            "radius": 0.9 * w, "width": 1.1 * w}


def leg_mesh(ctx):
    """One crab leg (thigh, knee, shin, foot), the hip at the origin, reaching out along +X. It is
    symmetric front to back, so the other side's legs are the same mesh turned half round."""
    t = 0.09 * ctx.limb
    return ctx.pet.library.compose("leg", [
        ("can", (0.18, 0, 0.06), (t, t, 0.2), (0, D(-70), 0)),
        ("ball", (0.36, 0, 0.08), (t * 1.15,) * 3, (0, 0, 0)),
        ("can", (0.4, 0, -0.26), (t * 0.9, t * 0.9, 0.31), (0, D(8), 0)),
        ("ball", (0.44, 0, -0.6), (t * 1.15, t * 1.15, t * 0.8), (0, 0, 0)),
    ])


def crab(ctx, p):
    w = p.get("w", 1.0)
    left, right = p.get("claws", (1.0, 1.0))
    legs = p.get("legs", 3)
    if p.get("boxy"):
        ctx.put("block", (0, 0, 0.85), (1.0 * w, 0.75, 0.45), "shell")
        ctx.put("block", (0, 0.08, 1.22), (0.7 * w, 0.5, 0.12), "trim")
    else:
        ctx.put("ball_hi", (0, 0, 0.85), (1.0 * w, 0.8, 0.48), "shell")
        ctx.put("ball", (0, 0.08, 1.08), (0.72 * w, 0.55, 0.3), "trim")
    ctx.put("seam", (0, 0, 0.85), (0.99 * w, 0.79, 1.0), "glow")
    face(ctx, (0, -0.76, 0.9), 0.5, 0.14, -8)
    spots = [0.3, 0.0, -0.3][:legs] if legs <= 3 else [0.36, 0.12, -0.12, -0.36]
    leg = leg_mesh(ctx)
    for side in (-1, 1):
        name = "L" if side < 0 else "R"
        for index, y in enumerate(spots):
            ctx.put(leg, (side * 0.86 * w, y, 0.72), 1.0, "shell", (0, 0, 0 if side > 0 else math.pi), "leg" + name + "ABCD"[index])
        size = left if side < 0 else right
        if size <= 0:
            continue
        shoulder = Vector((side * 0.8 * w, -0.55, 0.88))
        claw = Vector((side * (0.8 * w + 0.35 * (size - 1) + 0.35), -1.05 - 0.15 * (size - 1), 1.15 + 0.2 * (size - 1)))
        reach = claw - shoulder
        ctx.put("can", tuple(shoulder + reach / 2), (0.1 * ctx.limb, 0.1 * ctx.limb, reach.length / 2), "shell", tuple(reach.to_track_quat("Z", "Y").to_euler()))
        ctx.put("ball", tuple(claw), (0.36 * size, 0.4 * size, 0.32 * size), "shell")
        ctx.put("block", tuple(claw + Vector((0, -0.43 * size, 0.13 * size))), (0.12 * size, 0.24 * size, 0.08 * size), "trim", (D(-15), 0, 0), "jawTop" + name)
        ctx.put("block", tuple(claw + Vector((0, -0.39 * size, -0.15 * size))), (0.1 * size, 0.2 * size, 0.07 * size), "shell", (D(15), 0, 0), "jawBot" + name)
        ctx.put("seam", tuple(claw), (0.31 * size,) * 3, "glow", (D(90), 0, 0))
    if ctx.style == "sharp":
        # A row of spikes down the plate: the silhouette's accent.
        for index, x in enumerate((-0.32, 0.0, 0.32)):
            ctx.put("cone", (x * w, 0.2, 1.2 if not p.get("boxy") else 1.3), (0.1, 0.1, 0.32 if index == 1 else 0.24), "trim", (D(-20), D(x * 50), 0))
    hull = ((0, 0, 0.85), (1.0 * w, 0.8, 0.48))
    return {"hull": hull, "top": (0, 0.1, 1.38), "center": (0, 0, 0.85), "radius": 1.1 * w, "width": 1.65 * w}


def whale(ctx, p):
    s = p.get("size", 1.0)
    fins = p.get("fins", 1.0)
    cz = 0.15 + 0.85 * s
    hull = ((0, 0.15 * s, cz), (0.95 * s, 1.2 * s, 0.85 * s))
    info = {"hull": hull}
    ctx.put("ball_hi", hull[0], hull[1], "shell")
    belly = "galaxy" if p.get("_galaxy") else "trim"
    ctx.put("ball_hi", (0, -0.15 * s, cz - 0.28 * s), (0.78 * s, 0.86 * s, 0.52 * s), belly)
    # The seam round the body where the belly starts (low, clear of the porthole).
    ctx.put("seam", (0, 0.15 * s, cz - 0.3 * s), (0.9 * s, 1.13 * s, 1.0), "glow")
    # The porthole face: a rim, dark glass, two eyes in it.
    eye = ctx.face["eye"]
    ctx.put("ring", (0, -0.99 * s, cz + 0.1 * s), (0.4 * s, 0.4 * s, 0.6 * s), "trim", (D(90), 0, 0))
    ctx.put("ball", (0, -0.96 * s, cz + 0.1 * s), (0.38 * s, 0.08 * s, 0.38 * s), "visor")
    for side in (-1, 1):
        ex = side * 0.15 * s
        ctx.put("dot" if ctx.style == "sharp" else "ball", (ex, -1.04 * s, cz + 0.12 * s), (0.08 * s * eye, 0.03, 0.12 * s * eye), "eyes", role="eye")
        if ctx.face["highlight"]:
            ctx.put("dot", (ex - 0.025 * s * eye, -1.07 * s, cz + 0.18 * s * eye), (0.025 * s * eye, 0.015, 0.025 * s * eye), "white", role="eye")
    for side in (-1, 1):
        name = "L" if side < 0 else "R"
        ctx.put("block", (side * 0.95 * s, -0.05, cz - 0.4 * s), (0.32 * s * fins, 0.18 * s, 0.06 * ctx.limb), "shell", (0, D(side * 25), 0), "flipper" + name)
        root = Vector(on_hull(info, (side * 0.35 * s, 1.45 * s, cz + 0.55 * s)))
        out = (root - Vector(hull[0])).normalized()
        ctx.put("block", tuple(root + out * 0.12 * s), (0.3 * s * fins, 0.14 * s, 0.06 * ctx.limb), "trim", (D(30), D(side * 20), 0), "flukes")
    ctx.put("ball", (0, 0.35 * s, cz + 0.62 * s), (0.4 * s, 0.45 * s, 0.13 * s), "core", role="core")
    ctx.put("can", (0, 1.35 * s, cz + 0.1 * s), (0.22 * s, 0.22 * s, 0.13 * s), "engine", (D(90), 0, 0))
    ctx.put("ball", (0, 1.47 * s, cz + 0.1 * s), (0.16 * s, 0.05, 0.16 * s), "glow")
    if ctx.style == "sharp":
        # A dorsal fin: the silhouette's accent.
        base = on_hull(info, (0, 0.55 * s, cz + 0.9 * s), -0.05)
        ctx.put("cone", base, (0.06, 0.32 * s, 0.5 * s), "trim", (D(-25), 0, 0))
    return {"hull": hull, "top": (0, 0.15 * s, cz + 0.85 * s), "center": hull[0], "radius": 1.2 * s, "width": 1.5 * s, "size": s}


FAMILIES = {"slime": slime, "crab": crab, "whale": whale}


# --- Signatures (one shared set of meshes a post) --------------------------------------------------------


def siren(ctx, info):
    x, y = info["top"][0], info["top"][1]
    tz = top_height(info, x, y)
    ctx.put("block", (x, y, tz + 0.03), (0.3, 0.1, 0.06), "engine")
    ctx.put("ball", (x - 0.16, y, tz + 0.13), (0.11, 0.09, 0.09), "red")
    ctx.put("ball", (x + 0.16, y, tz + 0.13), (0.11, 0.09, 0.09), "blue")
    info["crown_r"] = 0.44 if info["hull"][1][0] > 0.7 else 0.32
    info["beacon_at"] = (0.0, 0.32)
    (cx, cy, cz), (a, b, c) = info["hull"]
    ctx.put("block", on_hull(info, (cx, cy - b, cz - 0.45 * c), 0.02), (0.16, 0.04, 0.12), "badge")


def rotor(ctx, info):
    x, y = info["top"][0], info["top"][1]
    tz = info["top"][2] - 0.05
    ctx.put("can", (x, y, tz + 0.28), (0.04, 0.04, 0.35), "engine")
    blades = ctx.pet.library.compose("rotor", [
        ("block", (0, 0, 0), (0.7, 0.07, 0.02), (D(4), 0, D(20))),
        ("block", (0, 0, 0), (0.7, 0.07, 0.02), (D(-4), 0, D(110))),
    ])
    ctx.put(blades, (x, y, tz + 0.62), 1.0, "blade", role="rotor")
    ctx.put("ball", (x, y, tz + 0.64), (0.09, 0.09, 0.06), "glow", role="rotor")
    info["crown_lift"] = 0.0


def galaxy(ctx, info):
    # The belly patch is painted lilac in whale(); the stars over the back are particles in game,
    # here a few shared dots.
    (cx, cy, cz), (a, b, c) = info["hull"]
    if "size" not in info:
        # A slime's galaxy swirls low in its jelly, under the glass.
        ctx.put("ball", (cx, cy - 0.1 * b, cz - 0.4 * c), (0.6 * a, 0.55 * a, 0.3 * c), "galaxy")
    for index in range(6):
        angle = index * 2.4
        ctx.put("dot", on_hull(info, (cx + math.cos(angle) * 0.45 * a, cy + 0.4 * b + math.sin(angle) * 0.15 * b, cz + 0.6 * c), 0.01),
                (0.035,) * 3, "backStar")


def _ring_low(info, radius):
    """The lowest height of the hull round a ring of `radius` on top (where a band rests)."""
    x, y = info["top"][0], info["top"][1]
    return min(top_height(info, x + math.cos(t) * radius, y + math.sin(t) * radius) for t in (0, math.pi / 2, math.pi, 1.5 * math.pi))


def circlet(ctx, info):
    """A royal band with a jewel round the top of the head; the crown rests on it."""
    x, y = info["top"][0], info["top"][1]
    band = min(0.45, info["hull"][1][0] * 0.5)
    z = _ring_low(info, band) + 0.02
    ctx.put("ring", (x, y, z), (band, band, band * 1.6), "circlet")
    ctx.put("ball", (x, y - band, z - 0.04), (0.1, 0.06, 0.1), "jewel")
    info["crown_r"] = band
    info["crown_lift"] = 0.1
    (cx, cy, cz), (a, b, c) = info["hull"]
    for side in (-1, 1):
        ctx.put("ball", on_hull(info, (cx + side * a, cy - 0.3 * b, cz - 0.45 * c), -0.02), (0.16, 0.14, 0.07), "circlet", (0, D(side * 70), 0))


def snowcap(ctx, info):
    """A fluffy snow cap on top."""
    x, y = info["top"][0], info["top"][1] - 0.1
    z = top_height(info, x, y) - 0.05
    ctx.put("ball", (x, y, z), (0.62, 0.5, 0.2), "snow")
    for dx, dz in ((-0.42, -0.05), (0.38, -0.07), (0.0, 0.05)):
        ctx.put("ball", (x + dx, y - 0.1, z + dz), (0.18, 0.18, 0.14), "snow")
    info["crown_lift"] = 0.22


def ice_crown(ctx, info):
    """A ring of ice spikes on top, wide enough for the crown to sit inside it."""
    x, y = info["top"][0], info["top"][1]
    ring = min(0.52, info["hull"][1][0] * 0.6)
    if ring < 0.52:
        info["crown_r"] = max(0.22, ring - 0.2)
    for index in range(9):
        angle = index / 9 * math.tau
        out = Vector((math.cos(angle) * 0.35, math.sin(angle) * 0.35, 1.0))
        px, py = x + math.cos(angle) * ring, y + math.sin(angle) * ring
        ctx.put("cone", (px, py, top_height(info, px, py) - 0.03), (0.08, 0.08, 0.32 + 0.12 * (index % 2)), "ice",
                tuple(out.to_track_quat("Z", "Y").to_euler()))


def _star(ctx, at, size, key):
    mesh = ctx.pet.library.compose("star5", [("cone", (0, 0, 0), (0.45, 0.3, 1.4), (0, D(90 - index * 72), 0)) for index in range(5)]
                                   + [("ball", (0, 0, 0), (0.5, 0.35, 0.5), (0, 0, 0))])
    ctx.put(mesh, at, size, key)


def stars(ctx, info):
    """Gold stars over the front and a big one on top."""
    (cx, cy, cz), (a, b, c) = info["hull"]
    for index in range(5):
        angle = index / 5 * math.tau + 0.3
        _star(ctx, on_hull(info, (cx + math.cos(angle) * a * 0.7, cy - b * 0.6, cz + 0.2 + math.sin(angle) * c * 0.45), 0.02), 0.09, "starGold")
    x, y = info["top"][0], info["top"][1]
    _star(ctx, (x, y, top_height(info, x, y) + 0.12), 0.14, "starGold")
    info["crown_lift"] = 0.15
    info["beacon_at"] = (0.0, 0.32)


def flames(ctx, info):
    """Flames licking up from the top, like a candle: stand-ins the game hides and plays as
    particles (role flame)."""
    tx, ty, tz = info["top"]
    for dx, height in ((0.0, 0.85), (-0.22, 0.55), (0.24, 0.6)):
        ctx.put("cone", (tx + dx, ty, tz - 0.25), (0.18, 0.18, height), "flame", tuple(Vector((dx * 0.6, 0, 1)).to_track_quat("Z", "Y").to_euler()), "flame")
    info["crown_lift"] = 0.05


def _bolt(ctx, points):
    for a, b in zip(points, points[1:]):
        start, end = Vector(a), Vector(b)
        ctx.put("can", tuple((start + end) / 2), (0.035, 0.035, (end - start).length / 2), "bolt", tuple((end - start).to_track_quat("Z", "Y").to_euler()))


def lightning(ctx, info):
    """Two zigzag bolts leaping up off the sides of the head."""
    x, y = info["top"][0], info["top"][1]
    for side in (-1, 1):
        x0 = x + side * 0.42
        z0 = top_height(info, x0, y) - 0.03
        _bolt(ctx, [(x0, y, z0), (x0 + side * 0.25, y, z0 + 0.3), (x0 + side * 0.13, y, z0 + 0.45), (x0 + side * 0.4, y, z0 + 0.8)])


def smoke(ctx, info):
    """Glowing dots over the back (the shadow wisps are particles)."""
    (cx, cy, cz), (a, b, c) = info["hull"]
    for index in range(9):
        ctx.put("dot", on_hull(info, (cx - 0.25 * a + index * 0.0625 * a + 0.05 * math.sin(index), cy + 0.5 * b, cz + 0.6 * c + 0.1 * math.cos(index * 2))),
                (0.04,) * 3, "dot")


def void_core(ctx, info):
    """A tiny black hole hovering over the head: a dark ball in a burning ring."""
    x, y = info["top"][0], info["top"][1] + 0.2
    where = (x, y, top_height(info, x, y) + 0.95)
    ctx.put("ball", where, (0.22,) * 3, "void")
    ctx.put("ring", where, (0.36, 0.36, 0.5), "horizon", (D(70), 0, 0))
    ctx.put("seam", where, (0.5, 0.5, 0.5), "horizonOuter", (D(70), 0, 0))


def bubbles(ctx, info):
    """Acid bubbles: particles in game, nothing to model."""


SIGNATURES = {"siren": siren, "rotor": rotor, "galaxy": galaxy, "circlet": circlet, "snowcap": snowcap, "ice_crown": ice_crown, "stars": stars,
              "flames": flames, "lightning": lightning, "smoke": smoke, "void_core": void_core, "bubbles": bubbles}


# --- The tier outfit (one set of meshes for all kinds) ------------------------------------------------


def beacon(ctx, info):
    dx, dy = info.get("beacon_at", (0.18, 0.12))
    x, y = info["top"][0] + dx, info["top"][1] + dy
    z = top_height(info, x, y)
    ctx.put("can", (x, y, z + 0.17), (0.025, 0.025, 0.21), "engine", (0, D(12), 0))
    ctx.put("ball", (x + 0.05, y, z + 0.4), (0.085,) * 3, "tier")


def jetpack(ctx, info):
    tank = ctx.pet.library.compose("tank", [
        ("can", (0, 0, 0), (0.11, 0.11, 0.21), (0, 0, 0)),
        ("ball", (0, 0, 0.21), (0.11, 0.11, 0.07), (0, 0, 0)),
        ("cone", (0, 0, -0.36), (0.13, 0.13, 0.17), (0, 0, 0)),
    ])
    (cx, cy, cz), (a, b, c) = info["hull"]
    for side in (-1, 1):
        x, y, z = on_hull(info, (cx + side * 0.26, cy + b, cz + info.get("engine_z", 0.0)), 0.06)
        ctx.put(tank, (x, y, z), 1.0, "engine")
        ctx.put("seam", (x, y, z + 0.06), (0.115, 0.115, 0.6), "tier")
        ctx.put("block", on_hull(info, (cx + side * a * 0.78, cy + 0.05, cz + c * 0.6), 0.02), (0.22, 0.3, 0.07), "armour", (0, D(side * -40), 0))


WING_SWEEP = 38


def wings(ctx, info, size):
    (cx, cy, cz), (a, b, c) = info["hull"]
    r = info["radius"]
    span = (0.8 + 0.25 * r) * size * 2.0
    for side in (-1, 1):
        hinge = on_hull(info, (cx + side * r * 0.35, cy + r * 0.5, cz + 0.35), -0.03)
        # The other side is the same flat wing turned half round about the vertical (its faces are
        # alike), so no mirrored mesh is needed.
        turn = Euler((D(-10), 0, D(side * WING_SWEEP))).to_matrix() @ (Matrix.Rotation(math.pi, 3, "Z") if side < 0 else Matrix.Identity(3))
        rotation = tuple(turn.to_euler())
        name = "wingL" if side < 0 else "wingR"
        ctx.put("wing", hinge, span, "wing", rotation, name)
        ctx.put("wing_edge", hinge, span, "wingEdge", rotation, name)


def crown(ctx, info):
    x, y = info["top"][0], info["top"][1]
    radius = info.get("crown_r", 0.32)
    z = min(top_height(info, x + math.cos(t) * radius, y + math.sin(t) * radius) for t in (0, math.pi / 2, math.pi, 1.5 * math.pi))
    z += 0.08 + info.get("crown_lift", 0.0)
    pieces = [("ring", (0, 0, -0.05 / 0.32), (1.0, 1.0, 2.2), (0, 0, 0))]
    gems = []
    for index in range(5):
        angle = index / 5 * math.tau - math.pi / 2
        out = Vector((math.cos(angle) * 0.25, math.sin(angle) * 0.25, 1)).normalized()
        base = Vector((math.cos(angle) * 0.94, math.sin(angle) * 0.94, -0.06))
        spike = (0.42 if index == 0 else 0.3) / 0.32
        pieces.append(("cone", tuple(base), (0.26, 0.26, spike), tuple(out.to_track_quat("Z", "Y").to_euler())))
        gems.append(("dot", tuple(base + out * spike), (0.18,) * 3, (0, 0, 0)))
    ctx.put(ctx.pet.library.compose("crown", pieces), (x, y, z), radius, "gold")
    ctx.put(ctx.pet.library.compose("gems", gems), (x, y, z), radius, "gemPink")


def star(ctx, info):
    """The legendary's medal: a gold star standing behind the pet (in place of today's sunburst
    stand-in, which the game hides and plays as particles)."""
    (cx, cy, cz), (a, b, c) = info["hull"]
    ctx.put("star", (cx, cy + b * 0.95, cz + 0.25), info["radius"] * 1.6, "gold", role="rays")


def tier_ring(ctx, info):
    ctx.put("washer", (0, 0, 0.03), (info["width"], info["width"], 0.3), "tier", role="ring")


def build(kind, tier, style, library, meteor=False, collection=None, dress=None, body_only=False):
    """One kind at the origin in a style, grown to `tier`; returns the pet (its objects, stats).
    `dress(ctx, info)` puts a rolled outfit (lowpoly_dress.py) in place of the fixed tier ladder."""
    kind_id, _, family, zone, look, shape, signature = kind[:7]
    colours = robo.theme(zone, look)["colours"]
    pet = kit.Pet(library, collection)
    ctx = Context(pet, colours, tier, meteor, style)
    names = [part.__name__ for part in signature]
    shape = dict(shape or {}, _galaxy="galaxy" in names)
    info = FAMILIES[family](ctx, shape)
    for name in names:
        # Signatures not sketched here (bubbles are particles anyway) are left out.
        if name in SIGNATURES:
            SIGNATURES[name](ctx, info)
    if zone == "debris" and not body_only:
        (cx, cy, cz), (a, b, c) = info["hull"]
        for step in range(min(tier, 3)):
            ctx.put("block", on_hull(info, (cx - 0.08 + step * 0.08, cy + b, cz - 0.6 * c), 0.01), (0.06, 0.05, 0.03), "engine" if step % 2 else "trim")
    if zone == "horizon" and tier >= 2 and not body_only:
        for index in range(tier - 1):
            angle = 2.0 + index * 2.6
            colour_key = "glow"
            ctx.put("ball", (info["center"][0] + math.cos(angle) * info["radius"] * 1.35, info["center"][1] + math.sin(angle) * info["radius"] * 0.8,
                             info["center"][2] + 0.45), (0.1,) * 3, colour_key, role="orbit")
    pet.info, pet.ctx = info, ctx
    if body_only:
        return pet
    if dress is not None:
        dress(ctx, info)
    elif 1 <= tier < 4:
        beacon(ctx, info)
    if dress is None and tier >= 2:
        jetpack(ctx, info)
    if dress is None and tier >= 3:
        wings(ctx, info, 0.85 if tier == 3 else 1.0)
    if dress is None and tier == 4:
        crown(ctx, info)
        star(ctx, info)
    pet.grow(GROWTH[tier])
    # No tier ring mesh: the game hides the export's ring and draws the tier on the floor itself.
    return pet


def kind(kind_id):
    return next(k for k in robo_kinds.KINDS if k[0] == kind_id)
