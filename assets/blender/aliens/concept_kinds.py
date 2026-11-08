# Concept sheet of all 24 alien kinds (decision 072): four rows, one per zone, each kind in the
# common tier on its ring. The tier outfit was agreed on the families sheet
# (concept_families.py); here each kind's own colour and detail are checked side by side.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/concept_kinds.py -- <out.png>

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import families  # noqa: E402
import kinds  # noqa: E402
import toon  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "concept_kinds.png"

SPACING = 3.9
ROW_HEIGHT = 3.6
COLUMNS = 6
ZONES = ["Пояс обломков", "Ледяные кольца", "Красная туманность", "Горизонт событий"]


def build():
    toon.reset()
    rows = len(kinds.KINDS) // COLUMNS
    for index, kind in enumerate(kinds.KINDS):
        row, column = divmod(index, COLUMNS)
        x = column * SPACING
        z = (rows - 1 - row) * ROW_HEIGHT

        def make(kind=kind, x=x, z=z):
            info = kinds.build_kind(kind, x, z)
            families.ring(x, z, info["width"], families.COMMON_RING)
            return info

        families.turned(x, z, make)
        toon.label(kind[1], (x, -1.4, z - 0.55), 0.24)
        if column == 0:
            toon.label(ZONES[row], (-2.9, -1.4, z + 0.9), 0.24)


def render():
    width = (COLUMNS - 1) * SPACING
    rows = len(kinds.KINDS) // COLUMNS
    height = rows * ROW_HEIGHT
    toon.render(
        OUT,
        width=width,
        height=height,
        center=(width / 2 - 1.0, 0, height / 2 - 0.6),
        ortho_scale=width + 5.4,
        resolution=(2400, 1720),
        camera_height=4.0,
        light_scale=1.5,
    )


build()
render()
print("Wrote", OUT)
