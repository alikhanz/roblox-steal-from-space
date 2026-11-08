# The 24 alien kinds (decision 072): one per guardian post, in the post order of
# GuardianConfig.POSTS (six per zone). Each is its guardian's baby — a family from families.py in
# the guardian's colour — with a detail of its own that tells it from its family's other kinds:
# a drone's propeller, a rusty crab's rivets, a fire slime's flames.

import math

import families
import toon
from families import GOLD, darker, lighter

WHITE = (0.97, 0.98, 1.0)


def propeller(x, z, info, color):
    # High over the eyes, so it shows above them.
    head, dy = info["head"], info.get("head_dy", 0.0)
    toon.cylinder("Mast", (x, dy, head + 0.45), 0.045, 0.9, (0.3, 0.32, 0.38))
    for spin in (0, 90):
        blade = toon.sphere("Blade", (x, dy, head + 0.92), (0.62, 0.1, 0.03), (0.88, 0.9, 0.96), 24)
        blade.rotation_euler = (0, 0, math.radians(spin + 30))
    toon.sphere("Hub", (x, dy, head + 0.92), (0.09, 0.09, 0.07), (1.0, 0.35, 0.3), 16)


def bubbles(x, z, info, color):
    for dx, dy, dz, size in ((-0.7, -0.4, 1.65, 0.12), (0.75, -0.3, 1.8, 0.09), (-0.2, -0.2, 2.0, 0.07), (0.95, -0.45, 1.2, 0.08)):
        toon.sphere("Bubble", (x + dx, dy, z + dz), (size, size, size), lighter(color, 0.6), 20, roughness=0.05, coat=1.0)


def rivets(x, z, info, color):
    center = info["center"]
    for dx, dz in ((-0.62, 0.05), (0.62, 0.05), (-0.3, 0.32), (0.3, 0.32), (0.0, 0.4)):
        toon.no_outline(toon.sphere("Rivet", (x + dx, -0.68 + abs(dx) * 0.18, center + dz), (0.06, 0.04, 0.06), darker(color, 0.55), 12))


def circlet(x, z, info, color):
    # A plain band round the top of the head: royal, but not the legendary crown with tips.
    head = info["head"] - 0.04
    toon.torus("Circlet", (x, 0, head), 0.52, 0.06, GOLD)
    toon.sphere("Jewel", (x, -0.55, head + 0.02), (0.08, 0.05, 0.08), (0.3, 0.7, 1.0), 12)


def frost(x, z, info, color):
    for dx, dy, dz in ((-0.4, -0.55, 0.45), (0.35, -0.6, 0.5), (0.0, -0.5, 0.62), (-0.55, -0.4, 0.2), (0.6, -0.45, 0.25)):
        toon.no_outline(toon.sphere("Frost", (x + dx, dy, info["center"] + dz), (0.05, 0.05, 0.05), WHITE, 12, emission=0.3))


def snowcap(x, z, info, color):
    cap = toon.sphere("Snow", (x, info.get("head_dy", 0.0), info["head"] + 0.02), (0.62, 0.5, 0.2), WHITE, 32, roughness=0.6, coat=0.1)
    for vertex in cap.data.vertices:
        if vertex.co.z < 0:
            vertex.co.z *= 0.3


def ice_spikes(x, z, info, color):
    ice = lighter(color, 0.6)
    for dx, tall, lean in ((-0.3, 0.32, 25), (0.0, 0.42, 0), (0.3, 0.32, -25), (-0.55, 0.2, 40), (0.55, 0.2, -40)):
        toon.cone("Ice", (x + dx, 0.0, info["head"] - 0.05 + tall / 2), 0.08, tall, ice, (0, math.radians(lean), 0), 4, roughness=0.05, coat=1.0)


def shards(x, z, info, color):
    # A crest of crystals on the head, between the feelers, and smaller ones down the back.
    crystal = lighter(color, 0.6)
    head = info["head"]
    for dx, dy, dz, tall, lean in ((-0.2, 0.05, head - 0.08, 0.36, 20), (0.0, 0.1, head - 0.02, 0.5, 0), (0.2, 0.05, head - 0.08, 0.36, -20)):
        toon.cone("Shard", (x + dx, dy, dz + tall / 2), 0.1, tall, crystal, (0, math.radians(lean), 0), 4, roughness=0.05, coat=1.0)
    for dy, dz, tall in ((0.38, z + 0.9, 0.34), (0.8, z + 0.7, 0.28)):
        toon.cone("Shard", (x, dy, dz + tall / 2), 0.09, tall, crystal, (math.radians(-20), 0, 0), 4, roughness=0.05, coat=1.0)


def bow(x, z, info, color):
    pink = (1.0, 0.45, 0.7)
    head = info["head"]
    for side in (-1, 1):
        loop = toon.sphere("BowLoop", (x + 0.32 + side * 0.17, -0.15, head - 0.02), (0.17, 0.08, 0.12), pink, 24)
        loop.rotation_euler = (0, math.radians(side * 20), 0)
    toon.sphere("BowKnot", (x + 0.32, -0.2, head - 0.02), (0.07, 0.07, 0.07), darker(pink, 0.15), 16)


def fangs(x, z, info, color):
    mouth = info["center"] - 0.17
    for side in (-1, 1):
        toon.cone("Fang", (x + side * 0.08, -0.66, mouth), 0.04, 0.12, WHITE, (math.radians(180), 0, 0), 8)


def flames(x, z, info, color):
    head = info["head"]
    for dx, tall in ((-0.28, 0.42), (0.0, 0.62), (0.28, 0.42)):
        toon.cone("Flame", (x + dx, 0.0, head - 0.05 + tall / 2), 0.15, tall, (1.0, 0.55, 0.12), vertices=12, emission=0.6)
        toon.cone("FlameCore", (x + dx, -0.07, head - 0.05 + tall * 0.35), 0.07, tall * 0.6, (1.0, 0.9, 0.35), vertices=12, emission=1.0)


def lightning(x, z, info, color):
    bolt = (1.0, 0.88, 0.2)
    for side in (-1, 1):
        for index, (dx, dz, tilt) in enumerate(((0.85, 1.32, 35), (1.05, 1.15, -35), (1.25, 1.32, 35))):
            streak = toon.no_outline(toon.sphere("Bolt", (x + side * dx, 0.0, z + dz), (0.05, 0.03, 0.16), bolt, 12, emission=1.2))
            streak.rotation_euler = (math.radians(-32), math.radians(side * tilt), 0)


def brood(x, z, info, color):
    families.bug(color, x - 1.25, z + 0.7, 0.34, False)
    families.bug(color, x + 1.2, z + 1.75, 0.32, False)


def glow_dots(dot):
    def draw(x, z, info, color):
        center, radius = info["center"], info["radius"]
        for dx, dz in ((-0.55, 0.35), (0.6, 0.3), (-0.75, -0.15), (0.72, -0.2), (0.0, 0.55)):
            toon.no_outline(toon.sphere("Glow", (x + dx * radius, -radius * 0.82, center + dz * radius), (0.06, 0.04, 0.06), dot, 12, emission=1.5))
    return draw


def orbit(x, z, info, color):
    # A small tilted orbit round the shell with a moon on it.
    ring = toon.torus("Orbit", (x, 0, info["center"] + 0.55), 1.3, 0.04, lighter(color, 0.55), emission=0.4)
    ring.rotation_euler = (math.radians(18), math.radians(12), 0)
    toon.sphere("Moon", (x + 1.25, -0.3, info["center"] + 0.85), (0.16, 0.16, 0.16), (0.9, 0.85, 0.7), 24)


def galaxy(x, z, info, color):
    for dx, dz, dot in ((-0.6, 0.45, (1.0, 0.55, 0.9)), (0.55, 0.55, (0.6, 0.7, 1.0)), (-0.85, 0.0, (0.75, 0.5, 1.0)),
                        (0.85, 0.05, (1.0, 0.8, 0.5)), (0.0, 0.72, (1.0, 1.0, 1.0)), (-0.3, 0.68, (0.6, 0.9, 1.0))):
        toon.no_outline(toon.sphere("Galaxy", (x + dx, -0.72, info["center"] + dz), (0.05, 0.03, 0.05), dot, 12, emission=2.0))


# (guardian id, Russian name, family, colour, details, family options)
KINDS = [
    # Debris Belt
    ("slimeWarden", "Слизень-сторож", "slime", (0.30, 0.82, 0.38), [], {}),
    ("crabDrone", "Краб-дрон", "crab", (0.46, 0.52, 0.62), [propeller], {}),
    ("violetCrab", "Лиловый краб", "crab", (0.64, 0.44, 0.92), [], {}),
    ("acidSlime", "Кислотный слизень", "slime", (0.70, 0.92, 0.18), [bubbles], {}),
    ("rustyCrab", "Ржавый краб", "crab", (0.78, 0.42, 0.20), [rivets], {}),
    ("slimeKing", "Король слизней", "slime", (0.62, 0.35, 0.86), [circlet], {}),
    # Ice Rings
    ("iceWorm", "Ледяной червь", "worm", (0.45, 0.80, 0.98), [frost], {}),
    ("snowCrab", "Снежный краб", "crab", (0.82, 0.90, 1.0), [snowcap, frost], {}),
    ("frostSlime", "Морозный слизень", "slime", (0.52, 0.90, 0.95), [ice_spikes], {}),
    ("crystalWorm", "Хрустальный червь", "worm", (0.92, 0.55, 0.86), [shards], {}),
    ("iceRay", "Ледяной скат", "ray", (0.38, 0.84, 0.88), [frost], {}),
    ("wormMother", "Мать червей", "worm", (0.27, 0.46, 0.88), [bow], {}),
    # Red Nebula
    ("devourerSwarm", "Рой пожирателей", "swarm", (0.92, 0.28, 0.55), [fangs], {}),
    ("starRay", "Звёздный скат", "ray", (0.32, 0.38, 0.95), [], {"star_color": GOLD}),
    ("fireSlime", "Огненный слизень", "slime", (1.0, 0.36, 0.10), [flames], {}),
    ("redSwarm", "Красный рой", "swarm", (0.90, 0.20, 0.20), [], {}),
    ("lightningRay", "Скат-молния", "ray", (0.25, 0.55, 1.0), [lightning], {}),
    ("devourerQueen", "Матка пожирателей", "swarm", (0.66, 0.16, 0.46), [fangs, brood], {}),
    # Event Horizon
    ("shadowWorm", "Теневой червь", "worm", (0.32, 0.24, 0.48), [glow_dots((0.75, 0.45, 1.0))], {}),
    ("blackRay", "Чёрный скат", "ray", (0.17, 0.17, 0.28), [], {"star_color": (0.75, 0.5, 1.0)}),
    ("voidSwarm", "Рой пустоты", "swarm", (0.27, 0.13, 0.42), [glow_dots((0.6, 0.5, 1.0))], {}),
    ("gravityCrab", "Гравикраб", "crab", (0.20, 0.56, 0.56), [orbit], {}),
    ("whaleCalf", "Китёнок", "whale", (0.45, 0.70, 0.95), [], {}),
    ("spaceWhale", "Космический Кит", "whale", (0.19, 0.21, 0.52), [galaxy], {"belly": (0.88, 0.6, 0.86)}),
]


def build_kind(kind, x, z):
    """Draws one kind's baby (common tier, no ring) at base point (x, 0, z); returns its anchors."""
    _, _, family, color, details, options = kind
    info = families.FAMILIES[family](x, z, color, **options)
    for detail in details:
        detail(x, z, info, color)
    return info
