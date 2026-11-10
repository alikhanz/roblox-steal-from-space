# Exports the twelve jetpacks (jetpacks.py) for the game as one GLB (decision 089).
#
# A jetpack rides on every character, so it is kept as light as it can be (user, 2026-11-10: "the
# jetpack must not eat too many resources"): the game's detail (jetpacks.LOW_POLY) and every part
# joined into one mesh per class of look — Shell (painted plastic), Metal (chrome and gold, the
# PetMetal variant in game), Glow (Neon) and Glass — at most four MeshParts a jetpack. Colours ride
# in the vertices (glTF COLOR_0, which Roblox multiplies with the part's colour; the game paints the
# parts white), so one mesh carries many colours.
#
# Node names carry everything the place needs:
#   J<grade>|<Class>    a part (Shell, Metal, Glow, Glass);
#   J<grade>|Origin     a tiny marker at the torso's centre: the model's pivot;
#   J<grade>|Nozzle<n>  a tiny marker at a nozzle's exit: an Attachment the flame leaves from.
# The markers become the pivot and attachments when the pack is put in the place, then go.
# Grades stand in a row along X, SPACING apart.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/jetpacks/export_jetpacks.py -- <out.glb>

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import jetpacks  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "out/jetpacks.glb"
SPACING = 4.0
# Budget per jetpack, checked on export.
MAX_TRIANGLES = 5000
MAX_PARTS = 4

jetpacks.LOW_POLY = True


def srgb(channel):
    channel = max(0.0, min(1.0, channel))
    return channel * 12.92 if channel <= 0.0031308 else 1.055 * channel ** (1 / 2.4) - 0.055


def look_of(mat):
    """The class a part joins and the colour (sRGB) it keeps in its vertices."""
    inputs = mat.node_tree.nodes.get("Principled BSDF").inputs
    base = inputs["Base Color"].default_value
    emission = inputs["Emission Color"].default_value
    if inputs["Alpha"].default_value < 0.99:
        return "Glass", base
    if inputs["Emission Strength"].default_value >= 1.0 and max(emission[:3]) > 0.2:
        return "Glow", emission
    if inputs["Metallic"].default_value >= 0.5:
        return "Metal", base
    return "Shell", base


def bake(obj, rgb):
    """Bakes a material colour (Blender's linear) into the vertices as Roblox will read it.

    Roblox reads COLOR_0 as sRGB numbers, not linear (BLENDER_ROBLOX.md, section 2), so the sRGB
    numbers go through the linear setter: the GLB then holds them unchanged. color_srgb would store
    them linear again and the jetpack would come out darker and richer than its material."""
    attribute = obj.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    colour = (srgb(rgb[0]), srgb(rgb[1]), srgb(rgb[2]), 1.0)
    for item in attribute.data:
        item.color = colour
    obj.data.color_attributes.active_color = attribute


def marker(name, location):
    """A tiny tetrahedron that only carries a name (a glTF node needs geometry to reach Roblox)."""
    mesh = bpy.data.meshes.new(name)
    s = 0.02
    mesh.from_pydata([(0, 0, 0), (s, 0, 0), (0, s, 0), (0, 0, s)], [], [(0, 1, 2), (0, 1, 3), (0, 2, 3), (1, 2, 3)])
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    return obj


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def build(grade, packed):
    """Builds one jetpack at its place in the row, joins it by class and moves it into `packed`."""
    x = grade * SPACING
    objects = jetpacks.build(grade, (x, 0, 0))
    nozzles = [obj for obj in objects if obj.get("role") == "nozzle"]
    meshes = [obj for obj in objects if obj.type in ("MESH", "CURVE")]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.convert(target="MESH")
    meshes = [obj for obj in bpy.context.view_layer.objects if obj.type == "MESH" and obj.select_get()]
    groups = {}
    for obj in meshes:
        look, rgb = look_of(obj.data.materials[0])
        bake(obj, rgb)
        groups.setdefault(look, []).append(obj)
    finished = []
    for look, members in sorted(groups.items()):
        # One material for all, so the joined mesh is one primitive.
        first = members[0].data.materials[0]
        for obj in members:
            obj.data.materials.clear()
            obj.data.materials.append(first)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in members:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = members[0]
        if len(members) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = joined.data.name = f"J{grade}|{look}"
        finished.append(joined)
    count = sum(triangles(obj) for obj in finished)
    print(f"Jetpack {grade}: {len(finished)} parts, {count} triangles, {len(nozzles)} nozzles")
    if count > MAX_TRIANGLES or len(finished) > MAX_PARTS:
        raise ValueError(f"jetpack {grade} is over budget: {len(finished)} parts, {count} triangles")
    finished.append(marker(f"J{grade}|Origin", (x, 0, 0)))
    for index, nozzle in enumerate(sorted(nozzles, key=lambda obj: obj.location.x), start=1):
        finished.append(marker(f"J{grade}|Nozzle{index}", nozzle.location))
        bpy.data.objects.remove(nozzle)
    for obj in finished:
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        packed.objects.link(obj)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    packed = bpy.data.collections.new("Packed")
    bpy.context.scene.collection.children.link(packed)
    for grade in range(len(jetpacks.GRADES)):
        build(grade, packed)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in packed.objects:
        obj.select_set(True)
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    options = dict(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=False, export_normals=True, export_materials="NONE")
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    print("Wrote", OUT, os.path.getsize(OUT), "bytes")


main()
