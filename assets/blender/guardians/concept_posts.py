# Concept sheet: the six guardians of one zone as adults, each with its baby (the post's main kind)
# beside it, three-quarter front. Two rows of three, in post order; a draft for review.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/guardians/concept_posts.py -- <out.png> <zone> [baby tier]

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))
sys.path.insert(0, HERE)

import adults  # noqa: E402
import bpy  # noqa: E402
import robo_kinds  # noqa: E402
from guardian_sheet import bounds, label, made, render, shift, turn  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "concept_posts.png"
ZONE = ARGS[1] if len(ARGS) > 1 else "debris"
TIER = int(ARGS[2]) if len(ARGS) > 2 else 1
YAW = -28
GAP = 1.0
COLUMNS = 3


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    posts = [index for index, post in enumerate(robo_kinds.POSTS) if post[0] == ZONE]
    cells = []
    for post in posts:
        kind = next(k for k in robo_kinds.KINDS if k[7] == post and k[8] == 0)
        adult = made(lambda kind=kind: adults.build(kind, 0, 0))
        turn(adult, 0, YAW)
        baby = made(lambda kind=kind: robo_kinds.build(kind, TIER, 0, 0))
        turn(baby, 0, YAW)
        low, high = bounds(adult)
        blow, bhigh = bounds(baby)
        cells.append((robo_kinds.POSTS[post][1], adult, low, high, baby, blow, bhigh))
    cell_width = max((c[3].x - c[2].x) + GAP + (c[6].x - c[5].x) for c in cells) + GAP * 2.5
    tallest = max(c[3].z for c in cells)
    size = max(0.3, cell_width * COLUMNS / 55)
    row_height = tallest + size * 5.5
    for index, (name, adult, low, high, baby, blow, bhigh) in enumerate(cells):
        column, row = index % COLUMNS, index // COLUMNS
        width = (high.x - low.x) + GAP + (bhigh.x - blow.x)
        left = column * cell_width + (cell_width - width) / 2
        dz = -row * row_height
        shift(adult, left - low.x, dz)
        shift(baby, left + (high.x - low.x) + GAP - blow.x, dz)
        label(name, (left + width / 2, 0, dz - size * 2.6), size)
    label(robo_kinds.ZONE_TITLES[ZONE], (cell_width * COLUMNS / 2, 0, tallest + size * 1.5), size * 1.5)
    return cell_width * COLUMNS, tallest


render(OUT, *build())
print("Wrote", OUT)
