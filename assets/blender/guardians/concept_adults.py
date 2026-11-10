# Concept sheet: an adult guardian next to its baby (the post's main kind), three-quarter front
# and side. One sheet per base family; a draft for review (POLISH queue, item 2).
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/guardians/concept_adults.py -- <out.png> <family> [baby tier] [big]
# `big` puts a legendary baby grown to the adult's size beside it instead (the rejected direction).

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))
sys.path.insert(0, HERE)

import adults  # noqa: E402
import bpy  # noqa: E402
import robo  # noqa: E402
import robo_kinds  # noqa: E402
from sheet import bounds, label, made, render, shift, turn  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "concept_adults.png"
FAMILY = ARGS[1] if len(ARGS) > 1 else "slime"
TIER = int(ARGS[2]) if len(ARGS) > 2 else 1
BIG = len(ARGS) > 3 and ARGS[3] == "big"
GAP = 1.2
# The six bases: the posts that set each body kind (GuardianLooks.KINDS).
BASES = {"slime": "slimeWarden", "crab": "crabDrone", "worm": "iceWorm", "swarm": "devourerSwarm", "ray": "starRay", "whale": "spaceWhale"}
FAMILY_TITLES = {"slime": "Слизень", "crab": "Краб", "worm": "Червь", "swarm": "Рой", "ray": "Скат", "whale": "Кит"}
TIER_TITLES = ["обычный", "необычный", "редкий", "эпический", "легендарный"]


def build():
    """Two rows, three-quarter front over side, each the adult with its baby to the right."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kind = adults.kind_of(BASES[FAMILY])
    rows = []
    for yaw, view in ((-28, "три четверти"), (90, "сбоку")):
        adult = made(lambda: adults.build(kind, 0, 0))
        turn(adult, 0, yaw)
        low, high = bounds(adult)
        if BIG:
            baby = made(lambda: robo_kinds.build(kind, 4, 0, 0))
            turn(baby, 0, yaw)
            blow, bhigh = bounds(baby)
            robo._grow(baby, 0, 0, (high.z - low.z) / (bhigh.z - blow.z))
            baby_title = "легендарный детёныш, увеличен"
        else:
            baby = made(lambda: robo_kinds.build(kind, TIER, 0, 0))
            turn(baby, 0, yaw)
            baby_title = f"детёныш · {TIER_TITLES[TIER]}"
        blow, bhigh = bounds(baby)
        rows.append((adult, low, high, baby, blow, bhigh, view, baby_title))
    width = max((r[2].x - r[1].x) + GAP + (r[5].x - r[4].x) for r in rows)
    tallest = max(r[2].z for r in rows)
    size = max(0.3, width / 40)
    row_height = tallest + size * 6.5
    for index, (adult, low, high, baby, blow, bhigh, view, baby_title) in enumerate(rows):
        dz = -index * row_height
        row_width = (high.x - low.x) + GAP + (bhigh.x - blow.x)
        left = (width - row_width) / 2
        shift(adult, left - low.x, dz)
        shift(baby, left + (high.x - low.x) + GAP - blow.x, dz)
        label(f"взрослый страж · {view}", (left + (high.x - low.x) / 2, 0, dz - size * 3.2), size)
        label(baby_title, (left + (high.x - low.x) + GAP + (bhigh.x - blow.x) / 2, 0, dz - size * 3.2), size * 0.8)
    label(f"{FAMILY_TITLES[FAMILY]}: {kind[1]}", (width / 2, 0, tallest + size * 1.5), size * 1.5)
    return width, tallest


render(OUT, *build())
print("Wrote", OUT)
