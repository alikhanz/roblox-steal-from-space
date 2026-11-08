# The six alien families as sci-fi robot pets (decision 074), each in a zone's theme: the common
# tier on top, the legendary below. Agrees the shells before the tier ladder and all 24 kinds.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/concept_robopets.py -- <out.png>

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

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "concept_robopets.png"
SPACING = 4.4
ROW_HEIGHT = 4.0
YAW = -25

# (label, family, zone)
COLUMNS = [
    ("Краб · Пояс обломков", "crab", "debris"),
    ("Слизень · Красная туманность", "slime", "nebula"),
    ("Червь · Ледяные кольца", "worm", "ice"),
    ("Скат · Ледяные кольца", "ray", "ice"),
    ("Рой · Красная туманность", "swarm", "nebula"),
    ("Кит · Горизонт событий", "whale", "horizon"),
]


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
    for column, (name, family, zone) in enumerate(COLUMNS):
        x = column * SPACING
        turned(x, ROW_HEIGHT, lambda x=x, family=family, zone=zone: robo.build(family, zone, 0, x, ROW_HEIGHT))
        turned(x, 0.0, lambda x=x, family=family, zone=zone: robo.build(family, zone, 4, x, 0.0))
        label(name, (x, -1.2, -0.85), 0.24)


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 2700, 1000
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    dark = nodes.get("Background")
    dark.inputs["Color"].default_value = (0.006, 0.008, 0.025, 1.0)
    
    # A smooth physical sky with a sun: clean reflections on gold, glass and glossy ceramic.
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

    width = (len(COLUMNS) - 1) * SPACING
    target = Vector((width / 2 - 0.6, 0, ROW_HEIGHT / 2 + 0.6))

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        if name != "Key":
            data.specular_factor = 0.0
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (target.x - 8, -12, target.z + 9), 5200, 10, (1.0, 0.97, 0.92))
    area("Fill", (target.x + 12, -10, target.z + 1), 1200, 12, (0.75, 0.85, 1.0))
    area("Rim", (target.x, 10, target.z + 6), 6000, 20, (0.55, 0.65, 1.0))

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 42
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = (target.x, -31, target.z + 4.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


build()
render()
print("Wrote", OUT)
