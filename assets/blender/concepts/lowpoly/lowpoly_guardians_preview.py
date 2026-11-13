# Concept check (decision 119): a guardian of each family as it is (robo.py's smooth primitives) and
# faceted (lowpoly_facets.py), one cell each, the same camera, to check the design survives.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_guardians_preview.py -- <outdir>

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for folder in ("lib", "aliens", "guardians", "lowpoly"):
    sys.path.insert(0, os.path.join(HERE, "..", "..", folder))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import lowpoly_render as render  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
render.OUT = ARGS[0] if ARGS else "out/lowpoly"
render.NEAR, render.FAR = 420, 48
KINDS = ["slimeWarden", "crabDrone", "iceWorm", "starRay", "devourerSwarm", "spaceWhale"]


def shoot_all(tag):
    import adults
    import robo
    import robo_kinds

    for kind_id in KINDS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        render.stage(4)
        robo.DETAIL = 0.5
        kind = next(k for k in robo_kinds.KINDS if k[0] == kind_id)
        adults.build(kind, 0.0, 0.0, growth=1.0)
        for obj in list(bpy.data.objects):
            if obj.get("role") == "fx":
                bpy.data.objects.remove(obj)
        camera = bpy.context.scene.camera
        target = render.TARGET * 2.4
        camera.location = target + render.VIEW * 2.4
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        render.shoot(f"guardian-{kind_id}-{tag}")


def main():
    shoot_all("today")
    import adults
    import lowpoly_facets
    import robo
    import robo_kinds

    lowpoly_facets.apply(robo, robo_kinds, adults)
    shoot_all("faceted")


if __name__ == "__main__":
    main()
