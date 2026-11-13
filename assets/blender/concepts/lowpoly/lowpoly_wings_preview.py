# Concept (low-poly pets): the wing kinds on one pet, epic and legendary, from the front three
# quarters and from behind (the game's camera often sees a pet's back). Writes cells and one sheet.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_wings_preview.py -- <outdir> [kind]

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "lowpoly"))

import bpy  # noqa: E402
import lowpoly_render as render  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "out/lowpoly"
KIND = ARGS[1] if len(ARGS) > 1 else "slimeWarden"
render.OUT = OUT


def main():
    import lowpoly_dress as dress
    import lowpoly_kit as kit
    import lowpoly_pets as pets

    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit._MATERIALS.clear()
    render.stage(3)
    library = kit.Library("faceted")
    cells = []
    for wing in list(dress.WING_TYPES) + ["angelSmall", "butterflySmall"]:
        for tier in ((3, 4) if not wing.endswith("Small") else (2,)):
            collection = bpy.data.collections.new(f"{wing}-{tier}")
            bpy.context.scene.collection.children.link(collection)
            picks = {"head": "crown" if tier == 4 else None, "aura": None, "back": wing}
            pets.build(pets.kind(KIND), tier, "faceted", library, False, collection, dress.dresser(picks))
            collection.hide_render = True
            cells.append((collection, tier, f"wings-{wing}-{tier}"))
    camera = bpy.context.scene.camera
    for collection, tier, name in cells:
        collection.hide_render = False
        render.frame(tier)
        render.shoot(name + "-front")
        # From behind and above, as the game's camera often is.
        target = render.TARGET * (render.GROWTH[tier] if tier < 4 else 1.6)
        offset = camera.location - target
        camera.location = target + Vector((-offset.x * 0.6, -offset.y, offset.z * 1.2))
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        render.shoot(name + "-back")
        collection.hide_render = True
    print("CELLS", [c[2] for c in cells])


if __name__ == "__main__":
    main()
