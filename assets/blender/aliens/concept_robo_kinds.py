# All 24 kinds as robot pets (decision 074), a row per zone from the easiest: checks that kinds of
# one zone differ in silhouette and signature, not only in colour. A draft for review.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/concept_robo_kinds.py -- <out.png> [tier]

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import real  # noqa: E402
import robo_kinds  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "concept_robo_kinds.png"
TIER = int(ARGS[1]) if len(ARGS) > 1 else 1
SPACING = 4.8
ROW_HEIGHT = 4.6
YAW = -25
PER_ROW = 6


def turned(x, z, make):
    before = set(bpy.data.objects)
    make()
    bpy.context.view_layer.update()
    pivot = Matrix.Translation(Vector((x, 0, z)))
    rotation = pivot @ Matrix.Rotation(math.radians(YAW), 4, "Z") @ pivot.inverted()
    for obj in set(bpy.data.objects) - before:
        obj.matrix_world = rotation @ obj.matrix_world


def label(text, location, size):
    bpy.ops.object.text_add(location=location, rotation=(math.radians(82), 0, 0))
    obj = bpy.context.active_object
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = size
    try:
        obj.data.font = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
    except RuntimeError:
        pass
    real.assign(obj, real.glow("Label", (0.75, 0.8, 0.95), 1.2))


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows = len(robo_kinds.KINDS) // PER_ROW
    for index, kind in enumerate(robo_kinds.KINDS):
        row, column = divmod(index, PER_ROW)
        x = column * SPACING
        z = (rows - 1 - row) * ROW_HEIGHT
        turned(x, z, lambda kind=kind, x=x, z=z: robo_kinds.build(kind, TIER, x, z))
        label(kind[1], (x, -2.4, z - 0.75), 0.24)
        if column == 0:
            label(robo_kinds.ZONE_TITLES[kind[3]], (2.5 * SPACING, -2.4, z + 3.35), 0.3)


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 2700, 2150
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    # A touch under-exposed, so bright bodies keep their colour instead of burning to white.
    scene.view_settings.exposure = -0.6
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    dark = nodes.get("Background")
    dark.inputs["Color"].default_value = (0.006, 0.008, 0.025, 1.0)
    sky = nodes.new("ShaderNodeBackground")
    sky.inputs["Strength"].default_value = 0.35
    texture = nodes.new("ShaderNodeTexSky")
    links.new(texture.outputs["Color"], sky.inputs["Color"])
    path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(sky.outputs["Background"], mix.inputs[1])
    links.new(dark.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], nodes.get("World Output").inputs["Surface"])

    width = (PER_ROW - 1) * SPACING
    height = (len(robo_kinds.KINDS) // PER_ROW - 1) * ROW_HEIGHT
    target = Vector((width / 2, 0, height / 2 + 0.8))

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        if name != "Key":
            data.specular_factor = 0.0
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (target.x - 9, -14, target.z + 10), 7000, 12, (1.0, 0.97, 0.92))
    area("Fill", (target.x + 14, -12, target.z + 1), 1800, 14, (0.75, 0.85, 1.0))
    area("Rim", (target.x, 12, target.z + 6), 8000, 24, (0.55, 0.65, 1.0))

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 42
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = (target.x, -37, target.z + 4.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


build()
render()
print("Wrote", OUT)
