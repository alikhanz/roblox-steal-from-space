# Concept (low-poly pets): every kind in the faceted style at one tier with a rolled outfit, one cell
# each, for a look at all 72 before export.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_all_preview.py -- <outdir> [tier] [family]

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "lowpoly"))

import bpy  # noqa: E402
import lowpoly_render as render  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "out/lowpoly"
TIER = int(ARGS[1]) if len(ARGS) > 1 else 3
FAMILY = ARGS[2] if len(ARGS) > 2 else None
render.OUT = OUT
render.NEAR, render.FAR = 300, 32


def main():
    import lowpoly_dress as dress
    import lowpoly_kit as kit
    import lowpoly_pets as pets
    import robo_kinds

    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit._MATERIALS.clear()
    render.stage(TIER)
    library = kit.Library("faceted")
    cells = []
    for index, kind in enumerate(robo_kinds.KINDS):
        if FAMILY and kind[2] != FAMILY:
            continue
        collection = bpy.data.collections.new(kind[0])
        bpy.context.scene.collection.children.link(collection)
        picks = dress.roll(f"preview:{index}", TIER)
        pets.build(kind, TIER, "faceted", library, False, collection, dress.dresser(picks))
        collection.hide_render = True
        cells.append((collection, kind[0]))
    render.frame(TIER)
    for collection, name in cells:
        collection.hide_render = False
        render.shoot(f"all-{TIER}-{name}")
        collection.hide_render = True
    print("CELLS", len(cells))


if __name__ == "__main__":
    main()
