# The full grid of one zone (decisions 074, 075): its six main kinds down, the five tiers and the meteor
# variant across. One sheet per zone; a draft for review.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/concept_robo_grid.py -- <out.png> <zone>

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
OUT = ARGS[0] if ARGS else "concept_robo_grid.png"
ZONE = ARGS[1] if len(ARGS) > 1 else "debris"
SPACING = 5.4
ROW_HEIGHT = 5.0
YAW = -25
METEOR_TIER = 2
COLUMNS = ["Обычный", "Необычный", "Редкий", "Эпический", "Легендарный", "Метеоритный"]


def turned(x, z, make):
    before = set(bpy.data.objects)
    make()
    bpy.context.view_layer.update()
    pivot = Matrix.Translation(Vector((x, 0, z)))
    rotation = pivot @ Matrix.Rotation(math.radians(YAW), 4, "Z") @ pivot.inverted()
    for obj in set(bpy.data.objects) - before:
        obj.matrix_world = rotation @ obj.matrix_world


def label(text, location, size, align="CENTER"):
    bpy.ops.object.text_add(location=location, rotation=(math.radians(82), 0, 0))
    obj = bpy.context.active_object
    obj.data.body = text
    obj.data.align_x = align
    obj.data.size = size
    try:
        obj.data.font = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
    except RuntimeError:
        pass
    real.assign(obj, real.glow("Label", (0.75, 0.8, 0.95), 1.2))


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kinds = [kind for kind in robo_kinds.KINDS if kind[3] == ZONE and kind[8] == 0]
    for row, kind in enumerate(kinds):
        z = (len(kinds) - 1 - row) * ROW_HEIGHT
        for tier in range(5):
            x = tier * SPACING
            turned(x, z, lambda kind=kind, tier=tier, x=x, z=z: robo_kinds.build(kind, tier, x, z))
        x = 5 * SPACING
        turned(x, z, lambda kind=kind, x=x, z=z: robo_kinds.build(kind, METEOR_TIER, x, z, meteor=True))
        label(kind[1], (-3.2, -2.5, z + 0.9), 0.36, "RIGHT")
    top = (len(kinds) - 1) * ROW_HEIGHT + 4.2
    for column, name in enumerate(COLUMNS):
        label(name, (column * SPACING, -2.5, top), 0.4)
    label(robo_kinds.ZONE_TITLES[ZONE], (2.5 * SPACING, -2.5, top + 1.0), 0.55)
    return len(kinds)


def render(rows):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 2700, 2700
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

    width = 5 * SPACING
    height = (rows - 1) * ROW_HEIGHT
    target = Vector((width / 2 - 1.4, 0, height / 2 + 1.3))

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        if name != "Key":
            data.specular_factor = 0.0
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (target.x - 10, -16, target.z + 12), 9000, 14, (1.0, 0.97, 0.92))
    area("Fill", (target.x + 16, -14, target.z + 1), 2400, 16, (0.75, 0.85, 1.0))
    area("Rim", (target.x, 14, target.z + 8), 10000, 28, (0.55, 0.65, 1.0))

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 42
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = (target.x, -46, target.z + 4.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


render(build())
print("Wrote", OUT)
