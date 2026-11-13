# A look at the fitted back slots (lowpoly_fit.py): for each kind given, its body five times in a
# row (butterfly, angel, dragon, crystal, fairy wings), the wings at both ends of the game's beat
# (front row: down and forward, back row: up and back), with the crown and the star. One image a
# kind, seen from behind and above, where the game's camera mostly sees a pet.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_fit_preview.py -- <outdir> kind [kind ...]

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for folder in ("lib", "aliens", "lowpoly"):
    sys.path.insert(0, os.path.join(HERE, "..", "..", folder))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import lowpoly_fit as fitting  # noqa: E402
import lowpoly_kit as kit  # noqa: E402
import lowpoly_pets as pets  # noqa: E402
import lowpoly_render as render  # noqa: E402
import lowpoly_wings as wingkit  # noqa: E402
import robo  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "out/lowpoly/fit"
KINDS = ARGS[1:] or ["crabDrone", "iceWorm", "redSwarm", "starRay", "spaceWhale", "crystalSlime"]
SPACING = 5.0


def material(name, rgba, emission=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Alpha"].default_value = alpha
    if emission:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.blend_method = "BLEND" if alpha < 1 else "OPAQUE"
    return mat


def solid(name, verts, polys, mat, offset):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([v + offset for v in verts], [], polys)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind_id in KINDS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        kit._MATERIALS.clear()
        render.stage(2)
        bpy.data.objects.remove(bpy.data.objects["Floor"])
        library = kit.Library("faceted")
        holder = kit.Pet(library, bpy.context.scene.collection)
        ctx = pets.Context(holder, robo.theme("debris")["colours"], 2, False, "faceted")
        geometry = fitting.kit_geometry(ctx)
        wing_mat = material("Wing", (0.3, 0.85, 1.0, 1.0), 2.0, 0.55)
        gold = material("Gold", (1.0, 0.7, 0.15, 1.0), 0.3)
        kind = pets.kind(kind_id)
        for row, beat in enumerate((-1.0, 1.0)):
            for column, wing in enumerate(wingkit.WINGS):
                offset = Vector(((column - 2) * SPACING, row * SPACING, 0))
                collection = bpy.data.collections.new(f"{wing}{row}")
                bpy.context.scene.collection.children.link(collection)
                pet = pets.build(kind, 2, "faceted", library, False, collection, body_only=True)
                bpy.context.view_layer.update()
                points = fitting.fit(pet.info, pet.objects, geometry)
                for obj in pet.objects:
                    obj.location += offset
                for side in (-1, 1):
                    hinge, span = points["Wing" + ("L" if side < 0 else "R")]
                    moved, _ = fitting.wing_tree(geometry, wing, side, hinge, span, beat)
                    solid(f"w{side}", moved, geometry[fitting.wing_name(wing, side)][1], wing_mat, offset)
                for name, slot in (("crown", "Crown"), ("star", "Star")):
                    at, scale = points[slot]
                    verts, polys = geometry[name]
                    solid(name, [Vector(at) + v * scale for v in verts], polys, gold, offset)
        camera = bpy.context.scene.camera
        target = Vector((0, SPACING * 0.5, 1.0))
        camera.location = target + Vector((-4.0, 19.0, 13.0))
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        camera.data.lens = 32
        scene = bpy.context.scene
        scene.render.resolution_x, scene.render.resolution_y = 1600, 900
        scene.render.filepath = os.path.join(OUT, f"fit-{kind_id}.png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
