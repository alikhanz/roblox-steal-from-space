# The tier ladder (decision 073): one kind from each zone, in its zone's style, through all five
# tiers and the meteor variant. Agrees the zone styles, how strongly a tier grows and the effects
# before all 24 kinds are built.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/concept_ladder.py -- <out.png>

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import organic  # noqa: E402
import real  # noqa: E402
import zones  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "concept_ladder.png"
SPACING = 4.6
ROW_HEIGHT = 4.3
YAW = -28

# (row title, family, zone, colour)
ROWS = [
    ("Пояс обломков · Краб-дрон", "crab", "biotech", (0.46, 0.52, 0.62)),
    ("Ледяные кольца · Хрустальный червь", "worm", "crystal", (0.72, 0.9, 1.0)),
    ("Красная туманность · Огненный слизень", "slime", "living", (1.0, 0.36, 0.1)),
    ("Горизонт событий · Космический кит", "whale", "cosmic", (0.25, 0.25, 0.65)),
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
    rows = len(ROWS)
    for row, (title, family_name, zone, color) in enumerate(ROWS):
        family = organic.FAMILIES[family_name]
        z = (rows - 1 - row) * ROW_HEIGHT
        for tier in range(5):
            x = tier * SPACING
            turned(x, z, lambda tier=tier, x=x, z=z: zones.build_tier(family, zone, color, tier, x, z))
        x = 5 * SPACING
        turned(x, z, lambda x=x, z=z: zones.build_meteor(family, color, x, z))
        label(title, (2.5 * SPACING, -1.0, z + 3.0), 0.3)
    for column, name in enumerate(COLUMNS):
        label(name, (column * SPACING, -1.0, -1.0), 0.32)


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 2600, 1900
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"

    # Camera rays see dark space; reflections see a patchy nebula sky.
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    dark = nodes.get("Background")
    dark.inputs["Color"].default_value = (0.004, 0.005, 0.015, 1.0)
    sky = nodes.new("ShaderNodeBackground")
    sky.inputs["Strength"].default_value = 1.6
    clouds = nodes.new("ShaderNodeTexNoise")
    clouds.inputs["Scale"].default_value = 3.0
    clouds.inputs["Detail"].default_value = 6
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.4
    ramp.color_ramp.elements[0].color = (0.01, 0.01, 0.04, 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (0.6, 0.8, 1.0, 1)
    ramp.color_ramp.elements.new(0.55).color = (0.3, 0.15, 0.5, 1)
    links.new(clouds.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], sky.inputs["Color"])
    path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(sky.outputs["Background"], mix.inputs[1])
    links.new(dark.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], nodes.get("World Output").inputs["Surface"])

    width = 5 * SPACING
    height = (len(ROWS) - 1) * ROW_HEIGHT
    target = Vector((width / 2, 0, height / 2 + 0.9))

    def area(name, location, energy, size, color=(1.0, 1.0, 1.0)):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (target.x - 9, -12, target.z + 9), 6000, 10, (0.92, 0.95, 1.0))
    area("Fill", (target.x + 12, -10, target.z), 1400, 12, (1.0, 0.82, 0.72))
    area("Rim", (target.x, 10, target.z + 6), 7000, 20, (0.55, 0.6, 1.0))

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 40
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = (target.x, -35, target.z + 5.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


build()
render()
print("Wrote", OUT)
