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
        # Points moving parts turn on (`hinge<Name>`, World/RigMotion): exported as markers that become
        # attachments on the body.
        self.hinges = []
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
            "hover": ("N", c["glow"], 0, 0, "Hover"),
            "pipe": ("S", (0.45, 0.42, 0.4), 0, 0.35, "Pipe"),
            "fire": ("N", (1.0, 0.45, 0.1), 0, 0, "Exhaust"),
            "steel": ("S", (0.75, 0.85, 0.95), 0, 0.35, "Plow"),
            "auroraGreen": ("N", (0.3, 1.0, 0.6), 0, 0, "Aurora"),
            "auroraBlue": ("N", (0.5, 0.6, 1.0), 0, 0, "Aurora"),
            "auroraViolet": ("N", (0.8, 0.4, 1.0), 0, 0, "Aurora"),
            "frill": ("G", c["trim"], 0.5, 0, "Frill"),
            "jaw": ("S", (0.85, 0.85, 0.9), 0, 0.35, "Jaw"),
            "brood": ("G", c["core"], 0.4, 0, "Brood"),
            "rock": ("S", (0.35, 0.33, 0.38), 0, 0.02, "Rock"),
            "brass": ("S", (0.85, 0.62, 0.3), 0, 0.35, "Brass"),
            "lens": ("N", (0.6, 0.85, 1.0), 0, 0, "Lens"),
            "buzz": ("G", (0.8, 0.9, 1.0), 0.75, 0, "Wing"),
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
            "tierDeep": ("S", tuple(v * 0.45 for v in tier), 0, 0.02, "TierDeep"),
            "tierLight": ("S", tuple(v + (1 - v) * 0.5 for v in tier), 0, 0.02, "TierLight"),
            "panel": ("S", (0.02, 0.035, 0.12), 0, 0.1, "Panel"),
            "wing": ("G", tier, 0.8, 0, "EnergyWing"),
            "wingEdge": ("N", tier, 0, 0, "TierGlow"),
            "jet": ("N", tier, 0, 0, "Jet"),
        }
        letter, colour, transparency, reflectance, source = table[key]
        rgb = ",".join(str(round(srgb(v) * 255)) for v in colour[:3])
        return f"{letter}{rgb},{transparency:g},{reflectance:g},{source}"

    def hinge(self, name, point):
        self.hinges.append((name, tuple(point)))

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
            ctx.hinge("hingeLeg" + name + "ABCD"[index], (side * 0.86 * w, y, 0.72))
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
        ctx.hinge("hingeJaw" + name, claw + Vector((0, -0.22 * size, 0)))
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
        ctx.hinge("hingeFlipper" + name, (side * (0.95 - 0.3 * fins) * s, -0.05, cz - 0.4 * s))
        root = Vector(on_hull(info, (side * 0.35 * s, 1.45 * s, cz + 0.55 * s)))
        out = (root - Vector(hull[0])).normalized()
        ctx.put("block", tuple(root + out * 0.12 * s), (0.3 * s * fins, 0.14 * s, 0.06 * ctx.limb), "trim", (D(30), D(side * 20), 0), "flukes")
    ctx.hinge("hingeFlukes", (0, root.y, root.z))
    ctx.put("ball", (0, 0.35 * s, cz + 0.62 * s), (0.4 * s, 0.45 * s, 0.13 * s), "core", role="core")
    ctx.put("can", (0, 1.35 * s, cz + 0.1 * s), (0.22 * s, 0.22 * s, 0.13 * s), "engine", (D(90), 0, 0))
    ctx.put("ball", (0, 1.47 * s, cz + 0.1 * s), (0.16 * s, 0.05, 0.16 * s), "glow")
    if ctx.style == "sharp":
        # A dorsal fin: the silhouette's accent.
        base = on_hull(info, (0, 0.55 * s, cz + 0.9 * s), -0.05)
        ctx.put("cone", base, (0.06, 0.32 * s, 0.5 * s), "trim", (D(-25), 0, 0))
    return {"hull": hull, "top": (0, 0.15 * s, cz + 0.85 * s), "center": hull[0], "radius": 1.2 * s, "width": 1.5 * s, "size": s}


def worm(ctx, p):
    """A worm rearing up: segments (each a role, segA at the head, so the game runs a wave down it),
    a big head with a visor and two feelers."""
    count = p.get("segments", 4)
    rs = p.get("r", 1.0)
    close = min(1.0, rs * 0.95)
    previous = None
    for index in range(count):
        px = 0.2 + (0.24 * index + 0.06 * math.sin(index * 1.3)) * close
        py = 0.15 + 0.3 * index * close
        pz = max(0.24, 0.58 - 0.11 * index)
        r = max(0.16, 0.4 - 0.045 * index) * rs
        role = "seg" + "ABCDEFGH"[index]
        ctx.put("ball", (px, py, pz), (r, r, r * 1.05), "shell", (0, 0, index * 0.7), role)
        ctx.put("dot", (px, py - r * 0.6, pz + r * 0.2), (r * 0.42, r * 0.28, r * 0.42), "core", role=role)
        if previous:
            mid = Vector(((previous[0] + px) / 2, (previous[1] + py) / 2, (previous[2] + pz) / 2))
            direction = Vector((px - previous[0], py - previous[1], pz - previous[2]))
            ctx.put("seam", tuple(mid), (r * 0.78,) * 3, "glow", tuple(direction.to_track_quat("Z", "Y").to_euler()), role)
        previous = (px, py, pz)
    head_r = 0.58 * min(rs, 1.25)
    head_z = 0.5 + head_r
    ctx.put("ball_hi", (0, -0.1, head_z), (head_r, head_r * 0.95, head_r * 0.95), "shell")
    ctx.hinge("hingeHead", (0, -0.1, head_z))
    ctx.put("block", (0, 0.02, head_z + head_r * 0.8), (0.3, 0.22, 0.08), "trim")
    face(ctx, (0, -0.1 - head_r * 0.9, head_z + 0.03), 0.36 * head_r / 0.58, 0.13, -5)
    for side in (-1, 1):
        ctx.put("can", (side * 0.2, -0.05, head_z + head_r + 0.02), (0.022, 0.022, 0.18), "engine", (0, D(side * 15), 0))
        ctx.put("dot", (side * 0.25, -0.05, head_z + head_r + 0.2), (0.06,) * 3, "glow")
    hull = ((0, -0.1, head_z), (head_r, head_r * 0.95, head_r * 0.95))
    return {"hull": hull, "top": (0, -0.1, head_z + head_r), "center": (0.3, 0.3, 0.75), "radius": 0.95 * max(rs, 1.0),
            "width": 1.35 * max(rs, 1.0), "head": hull[0], "head_r": head_r}


def ray(ctx, p):
    """A drone-manta over a hover glow: inner and outer fins (roles finL, finOuterL…, each on its
    hinge, so the game beats them as a wave) and a tail of beads (tailA…F)."""
    span = p.get("span", 1.0)
    droop = p.get("droop", 12)
    lift = 0.45
    ctx.put("ball_hi", (0, 0.05, 0.8 + lift), (0.62, 0.75, 0.32), "shell")
    for side in (-1, 1):
        name = "L" if side < 0 else "R"
        turn = (0, D(side * -droop * 0.4), D(side * -14))
        ctx.put("ball", (side * 0.85 * span, 0.2, 0.82 + lift), (0.75 * span, 0.55, 0.1), "shell", turn, "fin" + name)
        up = Euler(turn).to_matrix() @ Vector((0, 0, 1))
        ctx.put("seam", tuple(Vector((side * 0.85 * span, 0.2, 0.82 + lift)) + up * 0.08), (0.45 * span, 0.45 * span, 0.45 * span), "glow", turn, "fin" + name)
        outer = (0, D(side * -droop * 2.2), D(side * -28))
        ctx.put("ball", (side * 1.55 * span, 0.42, 1.0 + lift), (0.45 * span, 0.32, 0.07), "shell", outer, "finOuter" + name)
        ctx.put("block", (side * 1.85 * span, 0.56, 1.12 + lift - droop * 0.004), (0.16, 0.1, 0.035), "trim", (0, D(side * -droop * 2.6), D(side * -32)), "finOuter" + name)
        ctx.hinge("hingeFin" + name, (side * 0.45, 0.2, 0.82 + lift))
        ctx.hinge("hingeFinOuter" + name, (side * 1.2 * span, 0.35, 0.95 + lift))
    ctx.put("ball", (0, 0.15, 1.0 + lift), (0.32, 0.4, 0.14), "core", role="core")
    face(ctx, (0, -0.7, 0.86 + lift), 0.32, 0.1, -12)
    if p.get("tail", True):
        for step in range(6):
            ctx.put("ball", (0, 0.85 + step * 0.11, 0.78 + lift - step * 0.025), (0.1 - step * 0.008,) * 3, "shell" if step < 5 else "glow",
                    role="tail" + "ABCDEF"[step])
    ctx.put("can", (0, 0.8, 0.92 + lift), (0.12, 0.12, 0.1), "engine", (D(90), 0, 0))
    ctx.put("ball", (0, 0.91, 0.92 + lift), (0.1, 0.04, 0.1), "glow")
    ctx.put("can", (0, 0.1, 0.12), (0.7 * span, 0.55, 0.012), "hover")
    hull = ((0, 0.05, 0.8 + lift), (0.62, 0.75, 0.32))
    return {"hull": hull, "top": (0, 0.05, 1.12 + lift), "center": (0, 0.1, 0.85 + lift), "radius": 1.2 * span, "width": 1.75 * span,
            "span": span, "lift": lift, "shoulders": False}


def _drone(ctx, at, size, role, buzz):
    x, y, z = at
    ctx.put("ball", (x, y, z), (0.55 * size, 0.5 * size, 0.5 * size), "shell", role=role)
    ctx.put("block", (x, y + 0.1 * size, z + 0.38 * size), (0.22 * size, 0.18 * size, 0.06 * size), "trim", role=role)
    eye = ctx.face["eye"]
    ctx.put("ball", (x, y - 0.46 * size, z + 0.03 * size), (0.33 * size, 0.06, 0.15 * size * min(eye, 1.2)), "visor", role=role)
    for side in (-1, 1):
        ctx.put("ball", (x + side * 0.12 * size, y - 0.5 * size, z + 0.04 * size), (0.06 * size * eye, 0.03, 0.08 * size * eye), "eyes",
                role=role)
        name = buzz + ("L" if side < 0 else "R")
        ctx.put("ball", (x + side * 0.55 * size, y + 0.15 * size, z + 0.35 * size), (0.4 * size, 0.2 * size, 0.03 * size), "buzz",
                (0, D(side * -20), 0), name)
        ctx.hinge("hinge" + name[0].upper() + name[1:], (x + side * 0.2 * size, y + 0.15 * size, z + 0.35 * size))
    ctx.put("dot", (x, y, z - 0.5 * size), (0.15 * size, 0.15 * size, 0.06 * size), "glow", role=role)


def swarm(ctx, p):
    """A lead drone and its little ones (each a role, drone1…, so the game flies them round it)."""
    main = p.get("main", 1.25)
    lead_z = 0.2 + 0.65 * main
    _drone(ctx, (0, 0, lead_z), main, "body", "buzz")
    import robo

    drones = []
    for index, (dx, dy, dz, size) in enumerate(robo.SWARM_SPOTS[:p.get("count", 2)]):
        at = (dx * (0.6 + 0.35 * main), dy, dz * (0.55 + 0.35 * main))
        _drone(ctx, at, size, f"drone{index + 1}", f"drone{index + 1}Buzz")
        drones.append((Vector(at), size))
    hull = ((0, 0, lead_z), (0.55 * main, 0.5 * main, 0.5 * main))
    return {"hull": hull, "top": (0, 0, lead_z + 0.5 * main), "center": (0, 0, lead_z), "radius": 0.8 * main, "width": 1.0 * main,
            "engine_z": -0.05 * main, "lead": hull[0], "lead_size": main, "drones": drones, "shoulders": False}


FAMILIES = {"slime": slime, "crab": crab, "whale": whale, "worm": worm, "ray": ray, "swarm": swarm}


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


def _lead(info):
    """The body a part sits on: a swarm's lead drone, a worm's head, or the whole pet."""
    if "lead" in info:
        return Vector(info["lead"]), info["lead_size"]
    if "head" in info:
        return Vector(info["head"]), info["head_r"] / 0.58
    return Vector(info["center"]), info["radius"] / 0.8


def pincers(ctx, info):
    """Two little claws held up in front, snapping like a crab's (jawTopL… on hinges)."""
    (lx, ly, lz), size = _lead(info)
    if "head" in info:
        r = info["head_r"]
        bases = [Vector(on_hull(info, (lx + side * r * 0.6, ly - r * 0.6, lz - r * 0.9))) for side in (-1, 1)]
    else:
        bases = [Vector(on_hull(info, (lx + side * 0.55 * size, ly - 0.6 * size, lz - 0.25))) for side in (-1, 1)]
    for side, base in zip((-1, 1), bases):
        name = "L" if side < 0 else "R"
        ctx.put("ball", tuple(base), (0.16, 0.2, 0.14), "trim")
        ctx.put("block", tuple(base + Vector((side * 0.05, -0.2, 0.08))), (0.06, 0.13, 0.04), "trim", (D(-20), 0, 0), "jawTop" + name)
        ctx.put("block", tuple(base + Vector((0, -0.18, -0.07))), (0.05, 0.11, 0.035), "trim", (D(20), 0, 0), "jawBot" + name)
        ctx.hinge("hingeJaw" + name, base + Vector((0, -0.08, 0)))


def exhausts(ctx, info):
    """A tank's exhaust pipes with glowing tips, and rivets over the brow."""
    (cx, cy, cz), (a, b, c) = info["hull"]
    for side in (-1, 1):
        fx, fy, fz = on_hull(info, (cx + side * 0.22, cy + b * 0.6, cz + c * 0.35))
        ctx.put("can", (fx, fy, fz + 0.35), (0.09, 0.09, 0.35), "pipe", (D(-15), 0, 0))
        ctx.put("dot", (fx, fy + 0.08, fz + 0.72), (0.07, 0.07, 0.03), "fire")
    for dx in (-0.6, -0.36, -0.12, 0.12, 0.36, 0.6):
        ctx.put("dot", on_hull(info, (cx + dx * a, cy - b * 0.68, cz + 0.5 * c)), (0.045, 0.03, 0.045), "pipe")


def icicles(ctx, info):
    """Icicles hanging from the belly."""
    (cx, cy, cz), (a, b, c) = info["hull"]
    for index in range(5):
        base = on_hull(info, (cx - a * 0.5 + index * a * 0.25, cy - 0.1, cz - c), -0.02)
        ctx.put("cone", base, (0.06, 0.06, 0.22 + 0.05 * (index % 2)), "ice", (D(180), 0, 0))


def plow(ctx, info):
    """An icebreaker's steel wedge on the nose."""
    (cx, cy, cz), (a, b, c) = info["hull"]
    r = info["radius"]
    for side in (-1, 1):
        ctx.put("block", (cx + side * 0.35 * r, cy - b * 1.05, cz - 0.15), (0.45 * r, 0.06, 0.28), "steel", (0, 0, D(side * 35)))
    ctx.put("cone", (cx, cy - b * 1.2, cz - 0.15), (0.12, 0.12, 0.3), "steel", (D(90), 0, 0))


def aurora(ctx, info):
    """Northern lights rippling over the pet: three ribbons of faceted panels."""
    cx, cy, cz = info["center"]
    r = info["radius"]
    for band, key in enumerate(("auroraGreen", "auroraBlue", "auroraViolet")):
        for step in range(7):
            t = step / 6 - 0.5
            ctx.put("block", (cx + t * 2.2 * r, cy + 0.3 + band * 0.18, cz + r + 0.4 + band * 0.12 + 0.12 * math.sin(step * 1.3 + band)),
                    (0.17 * r, 0.015, 0.16), key, (0, D(15 * math.sin(step + band)), 0))


def ice_fringe(ctx, info):
    """Icicles along the trailing edges (a ray's fins, or round the body)."""
    cx, cy, cz = info["center"]
    span = info.get("span", 0.55)
    for side in (-1, 1):
        for index in range(4):
            reach = 0.5 + index * 0.38
            role = (("fin" if index < 2 else "finOuter") + ("L" if side < 0 else "R")) if "span" in info else "body"
            ctx.put("cone", (cx + side * reach * span, cy + 0.6 + index * 0.06, cz - 0.02 + index * 0.08), (0.05, 0.05, 0.2), "ice", (D(160), 0, 0), role)


def frill(ctx, info):
    """A fan collar round the head: seven petals."""
    if "head" in info:
        h, r = Vector(info["head"]), info["head_r"]
    else:
        h, r = Vector(info["center"]), info["radius"] * 0.7
    for index in range(7):
        angle = D(-70 + index * 23)
        out = Vector((math.sin(angle), 0.35, math.cos(angle))).normalized()
        root = Vector(on_hull(info, tuple(h + Vector((0, 0.25, 0)) + out * r)))
        ctx.put("ball", tuple(root + out * 0.22), (0.14, 0.04, 0.32), "frill", tuple(out.to_track_quat("Z", "Y").to_euler()))


def babies(ctx, info):
    """A mother worm's frill and two little worms beside her."""
    frill(ctx, info)
    hx, hy, hz = info.get("head", info["center"])
    for side in (-1, 1):
        bx = hx + side * 1.15
        for step in range(3):
            s = 0.17 - 0.03 * step
            ctx.put("ball", (bx + side * step * 0.05, -0.2 + step * 0.17, hz - 0.95 + (0.2 if step == 0 else 0.12 - 0.04 * step)), (s, s, s), "shell")
        face(ctx, (bx, -0.37, hz - 0.72), 0.12, 0.05)


def mandibles(ctx, info):
    """Curved jaws in front (mandL, mandR on hinges); every little drone has its own."""
    (lx, ly, lz), size = _lead(info)
    for side in (-1, 1):
        name = "L" if side < 0 else "R"
        root = Vector((lx + side * 0.22 * size, ly - 0.42 * size, lz - 0.2 * size))
        direction = Vector((-side * 0.6, -1, -0.3)).normalized()
        ctx.put("cone", tuple(root), (0.07 * size, 0.07 * size, 0.42 * size), "jaw", tuple(direction.to_track_quat("Z", "Y").to_euler()), "mand" + name)
        ctx.hinge("hingeMand" + name, root)
    for index, (location, s) in enumerate(info.get("drones", [])):
        for side in (-1, 1):
            name = f"drone{index + 1}Mand" + ("L" if side < 0 else "R")
            root = Vector((location.x + side * 0.1 * s, location.y - 0.4 * s, location.z - 0.15 * s))
            direction = Vector((-side * 0.6, -1, -0.3)).normalized()
            ctx.put("cone", tuple(root), (0.04 * s, 0.04 * s, 0.22 * s), "jaw", tuple(direction.to_track_quat("Z", "Y").to_euler()), name)
            ctx.hinge("hinge" + name[0].upper() + name[1:], root)


def crest(ctx, info):
    """A crest of spines down the back of the head."""
    (lx, ly, lz), size = _lead(info)
    y = info["top"][1]
    for index in range(5):
        angle = D(-40 + index * 20)
        px, py = lx + math.sin(angle) * 0.3 * size, y + 0.35 * size
        direction = Vector((math.sin(angle) * 0.6, 0.3, 1)).normalized()
        ctx.put("cone", (px, py, top_height(info, px, py) - 0.04), (0.07, 0.07, 0.35 + 0.15 * (index == 2)), "trim",
                tuple(direction.to_track_quat("Z", "Y").to_euler()))


def queen(ctx, info):
    """A queen's jaws, crest and glowing brood pods under her."""
    mandibles(ctx, info)
    crest(ctx, info)
    (lx, ly, lz), size = _lead(info)
    for dx, dy in ((-0.35, 0.1), (0.0, 0.25), (0.35, 0.1)):
        ctx.put("ball", on_hull(info, (lx + dx * size, ly + dy, lz - 0.75 * size), 0.06), (0.14, 0.14, 0.18), "brood")


def guard(ctx, info):
    mandibles(ctx, info)
    crest(ctx, info)


def minions(ctx, info):
    """Three tiny drones buzzing round the pet (drone1…, flown round it like a swarm's)."""
    cx, cy, cz = info["center"]
    r = info["radius"] + 0.35
    for index in range(3):
        angle = index / 3 * math.tau + 0.9
        at = (cx + math.cos(angle) * r, cy + math.sin(angle) * r * 0.5 - 0.2, cz + 0.4 + 0.3 * index)
        _drone(ctx, at, 0.3, f"drone{index + 1}", f"drone{index + 1}Buzz")


def star_dots(ctx, info):
    """Star dots over the fins or the back."""
    cx, cy, cz = info["center"]
    span = info.get("span", info["radius"] * 0.5)
    for side in (-1, 1):
        for reach, dy in ((0.5, 0.0), (0.9, 0.25), (1.3, 0.1), (1.65, 0.4), (1.1, 0.5)):
            role = (("fin" if reach < 1.2 else "finOuter") + ("L" if side < 0 else "R")) if "span" in info else "body"
            ctx.put("dot", (cx + side * reach * span, cy + 0.15 + dy - 0.5, cz + 0.17 + reach * 0.12), (0.04,) * 3, "dot", role=role)


def gravity(ctx, info):
    """Rocks held in orbit and a glowing anti-gravity ring beneath."""
    cx, cy, cz = info["center"]
    r = info["radius"]
    for index in range(4):
        angle = index / 4 * math.tau + 0.4
        ctx.put("ball", (cx + math.cos(angle) * (r + 0.2), cy + math.sin(angle) * 0.9, cz + 0.75 + 0.15 * math.sin(index * 2)), (0.16, 0.13, 0.12),
                "rock", (index, index * 0.5, 0), "orbit")
    base = info["top"][2] - (info["top"][2] - cz) * 2 - 0.05
    ctx.put("seam", (cx, cy, max(base, cz - 1.2, 0.05)), (r + 0.25,) * 3, "glow")


def telescope(ctx, info):
    """A stargazer's brass telescope on its back, pointed at the sky."""
    x, y = info["top"][0] + 0.3, info["top"][1] + 0.4
    turn = Euler((D(-35), D(25), 0))
    axis = turn.to_matrix() @ Vector((0, 0, 1))
    foot = Vector((x, y, top_height(info, x, y) - 0.03))
    ctx.put("can", tuple(foot + axis * 0.35), (0.09, 0.09, 0.35), "brass", tuple(turn))
    ctx.put("ball", tuple(foot + axis * 0.72), (0.1,) * 3, "lens")


def none(ctx, info):
    """Particles in game (bubbles, flakes, a spout): nothing to model."""


SIGNATURES = {"siren": siren, "rotor": rotor, "galaxy": galaxy, "circlet": circlet, "snowcap": snowcap, "ice_crown": ice_crown, "stars": stars,
              "flames": flames, "lightning": lightning, "smoke": smoke, "void_core": void_core, "bubbles": bubbles,
              "pincers": pincers, "exhausts": exhausts, "icicles": icicles, "plow": plow, "aurora": aurora, "ice_fringe": ice_fringe,
              "frill": frill, "babies": babies, "mandibles": mandibles, "crest": crest, "queen": queen, "guard": guard,
              "minions": minions, "star_dots": star_dots, "gravity": gravity, "telescope": telescope, "flakes": none, "spout": none}


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
