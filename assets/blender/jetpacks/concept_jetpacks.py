# Concept sheet of the twelve jetpacks (jetpacks.py), Starter to Infinity, each on a plain torso
# seen from behind and a little to the side — how a pilot sees their own jetpack in flight. No
# flames: in the game they are beams (they move, so they are reviewed live).
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/jetpacks/concept_jetpacks.py -- <out.png> [view] [low]
# view: back (default), three or side; add "low" for the game's detail.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import jetpacks  # noqa: E402
import real  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "concept_jetpacks.png"
VIEW = ARGS[1] if len(ARGS) > 1 else "back"
# "low": the game's meshes (jetpacks.LOW_POLY), to check they still read.
jetpacks.LOW_POLY = len(ARGS) > 2 and ARGS[2] == "low"
COLUMNS = 4
SPACING = 4.0
ROW_HEIGHT = 5.0
# Turned so the camera behind sees the pack three-quarter.
YAW = math.radians({"back": 0, "three": 38, "side": 90}[VIEW])


def mannequin(location, yaw):
    """A plain torso, head and upper arms: the scale of a character."""
    mat = real.gloss("Mannequin", (0.10, 0.11, 0.14), 0.5)
    before = set(bpy.data.objects)
    jetpacks.pill((0, 0, 0), (1.0, 0.5, 0.8), "dummy", mat, roundness=0.25)
    jetpacks.pill((0, 0, -1.15), (0.95, 0.48, 0.35), "dummy", mat, roundness=0.4)
    jetpacks.sphere((0, 0, 1.45), 0.62, "dummy", mat, scale=(1, 1, 1.05))
    for side in (-1, 1):
        jetpacks.pill((side * 1.25, 0, 0.1), (0.24, 0.24, 0.7), "dummy", mat, roundness=0.6)
    placed = Matrix.Translation(Vector(location)) @ Matrix.Rotation(yaw, 4, "Z")
    for obj in set(bpy.data.objects) - before:
        obj.matrix_world = placed @ obj.matrix_world


def label(text, location):
    bpy.ops.object.text_add(location=location, rotation=(math.radians(80), 0, math.pi))
    obj = bpy.context.active_object
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = 0.42
    try:
        obj.data.font = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
    except RuntimeError:
        pass
    real.assign(obj, real.glow("Label", (0.75, 0.8, 0.95), 1.2))


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows = math.ceil(len(jetpacks.GRADES) / COLUMNS)
    for grade, g in enumerate(jetpacks.GRADES):
        row, column = divmod(grade, COLUMNS)
        # Seen from behind (+Y), screen right is −X: columns run towards −X.
        x = -column * SPACING
        z = (rows - 1 - row) * ROW_HEIGHT
        mannequin((x, 0, z), YAW)
        jetpacks.build(grade, (x, 0, z), YAW)
        label(f"{grade}. {g['name']}", (x, 1.5, z - 2.0))
    return rows


def render(rows):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 2400, 2200
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.4
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

    width = (COLUMNS - 1) * SPACING
    height = (rows - 1) * ROW_HEIGHT
    target = Vector((-width / 2, 0, height / 2 - 0.2))

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        if name != "Key":
            data.specular_factor = 0.3
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    # Behind the characters is the camera side (+Y).
    area("Key", (target.x + 8, 16, target.z + 12), 7000, 14, (1.0, 0.97, 0.92))
    area("Fill", (target.x - 14, 12, target.z + 1), 2200, 16, (0.75, 0.85, 1.0))
    area("Rim", (target.x, -14, target.z + 8), 7000, 28, (0.55, 0.65, 1.0))

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 85
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = (target.x, 46, target.z + 14.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


render(build())
print("Wrote", OUT)
