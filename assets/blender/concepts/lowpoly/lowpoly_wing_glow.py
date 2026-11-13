# How much of each wing kind glows (decision 118): the surface area of its glowing lines (the
# `wingEdge` parts, Neon in the game) and of its faint membrane, per wing at scale 1. A legendary
# wears its pair at about 2.7 times that size (its anchor's Scale), so a pair's glowing area is about
# 2 * 2.7^2 = 14.6 times the line here. The accepted wings (user, 2026-11-13): butterfly 2.69,
# angel 2.18, dragon 1.37, crystal 0.54, fairy 0.74 (lines at WING_LIGHT.lineTransparency in the
# game). A new or changed wing keeps its line at or under the butterfly's (docs/design/WINGS.md).
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_wing_glow.py

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for folder in ("lib", "aliens", "lowpoly"):
    sys.path.insert(0, os.path.join(HERE, "..", "..", folder))

import bpy  # noqa: E402
import lowpoly_dress as dress  # noqa: E402
import lowpoly_kit as kit  # noqa: E402
import lowpoly_pets as pets  # noqa: E402
import lowpoly_wings as wingkit  # noqa: E402
import robo  # noqa: E402

LEGENDARY_SPAN = 2.665


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    library = kit.Library("faceted")
    ctx = pets.Context(kit.Pet(library, bpy.context.scene.collection), robo.theme("debris")["colours"], 2, False, "faceted")
    for wing in wingkit.WINGS:
        areas = {}
        for mesh, key in dress.wing_parts(ctx, wing):
            areas[key] = areas.get(key, 0.0) + sum(p.area for p in mesh.polygons)
        line = areas.get("wingEdge", 0.0)
        print(f"GLOW {wing:9} line {line:.3f} membrane {areas.get('wing', 0.0):.3f} legendary pair line {2 * line * LEGENDARY_SPAN ** 2:.1f} studs^2")


if __name__ == "__main__":
    main()
