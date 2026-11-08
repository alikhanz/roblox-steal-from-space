# How a robot pet grows (decision 074): one family per zone, easiest zone on top, through all five
# tiers and the meteor variant. The pet gets bigger and gains an outfit piece each tier; a harder
# zone adds a richer flair. A draft for review, not the final look.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/concept_robo_ladder.py -- <out.png>

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import real  # noqa: E402
import robo  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "concept_robo_ladder.png"
SPACING = 5.2
ROW_HEIGHT = 5.0
YAW = -25
METEOR_TIER = 2

# (row title, family, zone), from the easiest zone to the hardest
ROWS = [
    ("Пояс обломков · Краб", "crab", "debris"),
    ("Ледяные кольца · Червь", "worm", "ice"),
    ("Красная туманность · Слизень", "slime", "nebula"),
    ("Горизонт событий · Кит", "whale", "horizon"),
]
COLUMNS = ["Обычный", "Необычный", "Редкий", "Эпический", "Легендарный", "Метеоритный"]


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
    for row, (title, family, zone) in enumerate(ROWS):
        z = (len(ROWS) - 1 - row) * ROW_HEIGHT
        for tier in range(5):
            x = tier * SPACING
            turned(x, z, lambda tier=tier, x=x, z=z, family=family, zone=zone: robo.build(family, zone, tier, x, z))
        x = 5 * SPACING
        turned(x, z, lambda x=x, z=z, family=family, zone=zone: robo.build(family, zone, METEOR_TIER, x, z, meteor=True))
        label(title, (2.5 * SPACING, -1.5, z + 3.75), 0.32)
    for column, name in enumerate(COLUMNS):
        label(name, (column * SPACING, -3.0, -1.6), 0.34)


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 2700, 2100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    # A touch under-exposed, so bright bodies keep their colour instead of burning to white.
    scene.view_settings.exposure = -0.6
    # Camera rays see dark space; reflections see a smooth sky with a sun.
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
    height = (len(ROWS) - 1) * ROW_HEIGHT
    target = Vector((width / 2, 0, height / 2 + 0.9))

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
    camera.location = (target.x, -40, target.z + 4.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


build()
render()
print("Wrote", OUT)
