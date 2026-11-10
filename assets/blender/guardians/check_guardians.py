# Review sheet of the guardians as the game gets them (BLENDER_ROBLOX.md, sections 4 and 8): each
# post of a zone built, joined and thinned exactly as export_guardians_roblox.py does, then shown
# from the front, the side and the back (artefacts hide at the back). The baked parts are drawn in
# their vertex colours, as Roblox draws them.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/guardians/check_guardians.py -- <out.png> <zone>

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))
sys.path.insert(0, HERE)

import adults  # noqa: E402
import bpy  # noqa: E402
import export_guardians_roblox as export  # noqa: E402  (sets the detail and the paint rules)
import export_robo_roblox as pets  # noqa: E402
import robo_kinds  # noqa: E402
from guardian_sheet import bounds, label, render, shift, turn  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "check_guardians.png"
ZONE = ARGS[1] if len(ARGS) > 1 else "debris"
VIEWS = [(-20, "спереди"), (90, "сбоку"), (200, "сзади")]
GAP = 1.2


def baked_material():
    mat = bpy.data.materials.new("BakedPreview")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "Col"
    # The bake holds sRGB numbers (as Roblox reads them): back to linear for Blender's shading.
    gamma = nodes.new("ShaderNodeGamma")
    gamma.inputs["Gamma"].default_value = 2.2
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.3
    mat.node_tree.links.new(attribute.outputs["Color"], gamma.inputs["Color"])
    mat.node_tree.links.new(gamma.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def game_ready(kind):
    """The guardian as exported: joined, thinned; returns its parts (hinge markers dropped)."""
    adults.build(kind, 0.0, 0.0, growth=2.0)
    parts = pets.join_by_role()
    meshes = [obj for obj in bpy.context.view_layer.objects if obj.type == "MESH" and obj.name in parts]
    export.fit_budget([obj for obj in meshes if not obj.name.startswith("hinge")])
    shown = []
    preview = baked_material()
    for obj in meshes:
        if obj.name.startswith("hinge"):
            bpy.data.objects.remove(obj)
            continue
        if parts[obj.name].get("source") == pets.BAKED:
            obj.data.materials.clear()
            obj.data.materials.append(preview)
        shown.append(obj)
    return shown


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hold = bpy.data.collections.new("Done")
    bpy.context.scene.collection.children.link(hold)
    posts = [index for index, post in enumerate(robo_kinds.POSTS) if post[0] == ZONE]
    columns = []
    for post in posts:
        kind = next(k for k in robo_kinds.KINDS if k[7] == post and k[8] == 0)
        views = []
        for yaw, _ in VIEWS:
            objects = game_ready(kind)
            turn(objects, 0, yaw)
            for obj in objects:
                for collection in list(obj.users_collection):
                    collection.objects.unlink(obj)
                hold.objects.link(obj)
            views.append((objects, *bounds(objects)))
            # Finished ones leave the view layer, so the next join leaves them alone.
            bpy.context.view_layer.layer_collection.children["Done"].exclude = True
        columns.append((robo_kinds.POSTS[post][1], views))
    bpy.context.view_layer.layer_collection.children["Done"].exclude = False
    width = max(max(high.x - low.x for _, low, high in views) for _, views in columns) + GAP
    tallest = max(max(high.z for _, _, high in views) for _, views in columns)
    size = max(0.3, width * len(columns) / 60)
    row_height = tallest + size * 3
    for column, (name, views) in enumerate(columns):
        for row, (objects, low, high) in enumerate(views):
            shift(objects, column * width + (width - (high.x - low.x)) / 2 - low.x, -row * row_height)
        label(name, (column * width + width / 2, 0, tallest + size * 0.8), size)
    for row, (_, title) in enumerate(VIEWS):
        label(title, (-width * 0.35, 0, -row * row_height + tallest / 2), size)
    return width * len(columns), tallest


render(OUT, *build())
print("Wrote", OUT)
