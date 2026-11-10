# Concept renders for the jetpack stand's tiers (docs/plans/POLISH.md, "Тренажёр": the stand looks
# better with every trainer upgrade; brief docs/design/screens/jetpack-stand.md). Six tiers, a new
# model every three levels, the last one the top; between tiers a lamp of the dial on the platform's
# rim lights up per level. The stand itself is stand.py (the game's kit is built from it too);
# this script adds the shaders, the dial, a rider with a firing jetpack and the scene.
#
# Studs = Blender units. The stand's frame: the platform's centre on the floor, its top
# StandConfig.PLATFORM_HEIGHT (0.6) high; the rider faces -Y (the island's centre), the frame stands
# behind, +Y. In game the camera sits behind and above the rider.
#
# Style: the station's grey-blue steel (as the terminals, decision 086), pearl ceramic of the robot
# pets and the station's kiosks, the trainer's yellow for light; gold only on the top tier.
#
# Run headless from the repo root (PowerShell):
#   & "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python assets/blender/trainer/concept_stand.py -- <outdir> [view ...] [tier ...]
# Views: back (the game's camera), front. Tiers: 1..6. Add "low" for the game's detail.
# Writes <outdir>/stand_<view>_<tier>.png.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "jetpacks"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import jetpacks  # noqa: E402
import real  # noqa: E402
import stand  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/trainer")
VIEWS = [a for a in ARGS[1:] if a in ("back", "front")] or ["back", "front"]
TIERS = [int(a) for a in ARGS[1:] if a.isdigit()] or [1, 2, 3, 4, 5, 6]
# "low": the game's detail (stand_kit.py), to check it still reads.
stand.LOW_POLY = "low" in ARGS[1:]

P = stand.P

def srgb(r, g, b):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin(r), lin(g), lin(b))

# The station's steel (station-look's concept_station.py; the terminals use it too), linear.
STEEL = (0.30, 0.33, 0.42)
STEEL_LIGHT = (0.72, 0.75, 0.82)
STEEL_DARK = (0.12, 0.13, 0.19)
PEARL = (0.84, 0.86, 0.92)
NAVY = (0.035, 0.05, 0.12)
YELLOW = srgb(255, 214, 90)  # BayLooks.TRAINER_RING_COLOR
HOT = srgb(255, 140, 50)  # BayLooks.STAND_GRATE_HOT_COLOR
GOLD = (1.0, 0.72, 0.25)

# --- Materials ---------------------------------------------------------------------------------

_cache = {}

def mat(key, make):
    if key not in _cache:
        _cache[key] = make()
    return _cache[key]

def steel():
    return mat("steel", lambda: real.gloss("Steel", STEEL, roughness=0.32, metallic=0.35))

def steel_light():
    return mat("steelLight", lambda: real.gloss("SteelLight", STEEL_LIGHT, roughness=0.28, metallic=0.4))

def dark():
    return mat("dark", lambda: real.chrome("Dark", STEEL_DARK, roughness=0.3))

def pearl():
    return mat("pearl", lambda: real.gloss("Pearl", PEARL, roughness=0.18))

def navy():
    return mat("navy", lambda: real.gloss("Navy", NAVY, roughness=0.2))

def gold():
    return mat("gold", lambda: real.chrome("Gold", GOLD, roughness=0.18))

def glow(color=YELLOW, strength=4.0):
    return mat(("glow", color, strength), lambda: real.glow("Glow", color, strength))

def floor_mat():
    def make():
        m = real.gloss("Floor", srgb(40, 46, 70), roughness=0.85, metallic=0.1)
        # No clear coat: its highlight of the sun read as a white spot.
        m.node_tree.nodes.get("Principled BSDF").inputs["Coat Weight"].default_value = 0.0
        return m

    return mat("floor", make)

def flame_mat(color):
    """A soft jet (Beams in game): bright at its axis, fading at its edge."""

    def make():
        m = bpy.data.materials.new("Flame")
        m.use_nodes = True
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        nodes, links = m.node_tree.nodes, m.node_tree.links
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")
        em = nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*color, 1)
        em.inputs["Strength"].default_value = 6.0
        facing = nodes.new("ShaderNodeLayerWeight")
        facing.inputs["Blend"].default_value = 0.5
        inv = nodes.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        links.new(facing.outputs["Facing"], inv.inputs[1])
        clear = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        links.new(inv.outputs[0], mix.inputs["Fac"])
        links.new(clear.outputs[0], mix.inputs[1])
        links.new(em.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs[0])
        return m

    return mat(("flame", color), make)

# --- Shapes ------------------------------------------------------------------------------------

def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True

def local(obj, parent):
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)

def empty(name, location=(0, 0, 0), rotation=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.location = location
    obj.rotation_euler = rotation
    bpy.context.scene.collection.objects.link(obj)
    if parent:
        local(obj, parent)
    return obj

def rbox(size, location, material, bevel=0.15, rotation=(0, 0, 0), parent=None, segments=4):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = min(bevel, min(size) * 0.49)
        mod.segments = segments
        mod.limit_method = "NONE"
        smooth(obj)
        obj.modifiers.new("Normals", "WEIGHTED_NORMAL").keep_sharp = True
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj

def cyl(radius, depth, location, material, rotation=(0, 0, 0), vertices=64, radius2=None, parent=None, bevel=0.0):
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=radius2, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    smooth(obj)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj

def ball(radius, location, material, parent=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=32, ring_count=16)
    obj = bpy.context.active_object
    obj.scale = scale
    smooth(obj)
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj

def capsule(radius, height, location, material, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=32, ring_count=16)
    obj = bpy.context.active_object
    half = max(0.0, height / 2 - radius)
    for v in obj.data.vertices:
        v.co.z += half if v.co.z > 0 else -half if v.co.z < 0 else 0
    smooth(obj)
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj

# --- The stand (stand.py) with the concept's shaders -------------------------------------------

def role_materials():
    """What each role of stand.py looks like in the renders."""
    return {
        "steel": steel(),
        "light": steel_light(),
        "dark": dark(),
        "pearl": pearl(),
        "navy": navy(),
        "top": mat("top", lambda: real.gloss("Top", STEEL_DARK, 0.5, 0.3)),
        "gold": gold(),
        "glow": glow(YELLOW, 4),
        "hot": glow(HOT, 3.5),
        # On the stand with its rider the pilot lights are out; a dim blue shows where they are.
        "pilot": real.gloss("Pilot", srgb(60, 120, 160), 0.2),
    }

def dial(root, radius, level, z=P + 0.005):
    """The level dial (in game: BayModel's lamps): one lamp lit per level."""
    lit = min(level, stand.DIAL_LAMPS)
    for i, (x, y, deg) in enumerate(stand.dial_spots(radius)):
        lamp = rbox(stand.DIAL_LAMP, (x, y, z), glow(YELLOW, 5) if i < lit else dark(), 0.03, parent=root)
        lamp.rotation_euler = (0, 0, -math.radians(deg))

# --- The rider ---------------------------------------------------------------------------------

def rider(root, flame=1.0):
    """A blocky R15 player on the platform, facing -Y, hands on the rail, a jetpack firing."""
    skin = mat("skin", lambda: real.gloss("Skin", srgb(245, 205, 150), roughness=0.5))
    shirt = mat("shirt", lambda: real.gloss("Shirt", srgb(70, 110, 200), roughness=0.6))
    pants = mat("pants", lambda: real.gloss("Pants", srgb(40, 45, 60), roughness=0.6))
    for side in (-1, 1):
        rbox((0.9, 0.9, 2.0), (side * 0.48, 0, P + 1.0), pants, 0.12, parent=root)
    rbox((2.0, 1.0, 0.45), (0, 0, P + 2.2), pants, 0.12, parent=root)
    rbox((2.0, 1.0, 1.6), (0, 0, P + 3.2), shirt, 0.15, parent=root)
    rbox((1.15, 1.15, 1.15), (0, 0, P + 4.6), skin, 0.3, parent=root)
    # Arms reaching down-forward to the rail (hands at y -1.3, P + 2.6).
    for side in (-1, 1):
        shoulder = Vector((side * 1.5, 0, P + 3.85))
        hand = Vector((side * 1.35, -1.3, P + 2.65))
        mid = (shoulder + hand) / 2
        arm = rbox((0.9, 0.9, 2.0), mid, skin, 0.12, parent=root)
        arm.rotation_euler = (shoulder - hand).to_track_quat("Z", "Y").to_euler()
    # The jetpack (Comet) on the torso's back, its centre the torso's.
    before = set(bpy.data.objects)
    jetpacks.build(2, (0, 0, P + 3.2), 0.0)
    for obj in set(bpy.data.objects) - before:
        world = root.matrix_world @ obj.matrix_world
        obj.parent = None
        obj.matrix_world = world
        if obj.get("role") == "nozzle":
            # Its flame: a jet down and a little back, longer with the trainer's level.
            length = 1.6 * flame
            jet = cyl(0.2, length, (0, 0, 0), flame_mat((1.0, 0.75, 0.35)), radius2=0.02, vertices=24)
            core = cyl(0.09, length * 0.55, (0, 0, 0), flame_mat((1.0, 0.95, 0.85)), radius2=0.01, vertices=16)
            for part, l in ((jet, length), (core, length * 0.55)):
                # The marker's +Z points down the jet; the cone's wide end (its -Z) at the nozzle.
                part.matrix_world = obj.matrix_world @ Matrix.Translation((0, 0, l / 2))

def flame_scale(level):
    """Stand.flameScale with StandConfig's FLAME_MAX_SCALE 3, FLAME_FULL_LEVEL 20."""
    share = min(1.0, math.log(1 + level) / math.log(21))
    return 1 + 2 * share

# --- Scene -------------------------------------------------------------------------------------

def space():
    w = bpy.data.worlds.new("Space")
    bpy.context.scene.world = w
    w.use_nodes = True
    n, l = w.node_tree.nodes, w.node_tree.links
    bg = n.get("Background")
    coord = n.new("ShaderNodeTexCoord")
    noise = n.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.0
    noise.inputs["Detail"].default_value = 6.0
    l.new(coord.outputs["Generated"], noise.inputs["Vector"])
    ramp = n.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.45, (0.006, 0.007, 0.02, 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.8, (0.05, 0.03, 0.1, 1)
    l.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    l.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0

def lights(target):
    scene = bpy.context.scene
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.0
    sun.angle = math.radians(3)
    sun.color = (1.0, 0.95, 0.88)
    obj = bpy.data.objects.new("Sun", sun)
    obj.rotation_euler = (math.radians(50), math.radians(-25), math.radians(-35))
    scene.collection.objects.link(obj)
    for name, location, energy, colour, size in (
        ("Fill", (22, -20, 8), 4500, (0.6, 0.7, 1.0), 18),
        ("Back", (-14, 22, 12), 6000, (0.75, 0.7, 1.0), 20),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, colour
        data.specular_factor = 0.0
        light = bpy.data.objects.new(name, data)
        light.location = location
        light.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)

def label(body, location, size, camera_at):
    curve = bpy.data.curves.new("Label", "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = "CENTER"
    try:
        curve.font = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
    except RuntimeError:
        pass
    obj = bpy.data.objects.new("Label", curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(camera_at) - Vector(location)).to_track_quat("Z", "Y").to_euler()
    real.assign(obj, real.glow("Label", (0.8, 0.85, 1.0), 1.4))

CAMERAS = {
    # Behind and above the rider, a little to the side: the game's camera.
    "back": ((5.5, 13.0, 8.8), (0, 0.6, 2.4)),
    # Three-quarter front: the face, the rail, the dial.
    "front": ((-7.0, -11.5, 6.8), (0, 0.6, 2.4)),
}

def render(view, tier):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _cache.clear()
    camera_at, look_at = CAMERAS[view]
    space()
    lights(Vector(look_at))
    cyl(30, 1.0, (0, 0, -0.5), floor_mat(), vertices=96)
    info = stand.TIERS[tier - 1]
    level, name = info["from"], info["name"]
    root = empty("Stand")
    stand.MATERIALS.clear()
    stand.MATERIALS.update(role_materials())
    stand.build(tier)
    dial(root, info["dial"], level)
    rider(root, flame_scale(level))
    last = stand.TIERS[tier]["from"] - 1 if tier < len(stand.TIERS) else None
    levels = f"Ур. {level}–{last}" if last is not None else f"Ур. {level}+"
    label(f"{tier}. {name}", Vector(look_at) + Vector((0, 0, 6.6)), 0.95, camera_at)
    label(levels, Vector(look_at) + Vector((0, 0, 5.6)), 0.7, camera_at)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 48)):
        if hasattr(scene.eevee, attribute):
            setattr(scene.eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 900, 1000
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = 0.1
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 30
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = camera_at
    cam.rotation_euler = (Vector(look_at) + Vector((0, 0, 1.6)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT_DIR, f"stand_{view}_{tier}.png")
    bpy.ops.render.render(write_still=True)
    print("Wrote", scene.render.filepath)

for view in VIEWS:
    for tier in TIERS:
        render(view, tier)
