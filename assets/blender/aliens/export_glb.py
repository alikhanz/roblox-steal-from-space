# Exports every alien kind (kinds.py) as a GLB file for the 3D viewer page, in the common tier on
# its ring and the legendary tier in its full outfit: <outdir>/<guardian id>-common.glb and
# -legendary.glb. The glossy coat and the glow travel in the glTF materials; the cartoon outline
# is a render effect and does not. Round shapes are divided more coarsely than in the renders
# (toon.DETAIL) to keep 48 files small.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/export_glb.py -- out/aliens

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import families  # noqa: E402
import kinds  # noqa: E402
import toon  # noqa: E402

OUT_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "out/aliens"
toon.DETAIL = 0.6


def export(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for kind in kinds.KINDS:
        guardian = kind[0]

        toon.reset()
        info = kinds.build_kind(kind, 0.0, 0.0)
        families.ring(0.0, 0.0, info["width"], families.COMMON_RING)
        export(os.path.join(OUT_DIR, f"{guardian}-common.glb"))

        toon.reset()
        info = kinds.build_kind(kind, 0.0, 0.0)
        families.ring(0.0, 0.0, info["width"], families.GOLD)
        families.legendary_outfit(0.0, 0.0, info)
        export(os.path.join(OUT_DIR, f"{guardian}-legendary.glb"))
        print("Exported", guardian)


main()
