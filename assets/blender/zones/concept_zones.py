# Concept renders for the four zones (docs/plans/POLISH.md, queue: "space and light" and "nests"):
# one picture a zone, each with a nest on its asteroid (a wide pad to land on for a theft, user
# 2026-11-08) and four kinds of asteroid of that zone, so a zone is not one rock repeated, and the
# zone's own dressing (wreckage, ice shards, gas, crystals). A draft for review, not the final look.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/zones/concept_zones.py -- <outdir> [zone ...]
# Zones: debris, ice, nebula, horizon.

import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))

import bpy  # noqa: E402
import real  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/zones")
ZONES = ARGS[1:] or ["debris", "ice", "nebula", "horizon"]


# --- Materials ---------------------------------------------------------------------------------


def stone(name, light, dark, pits=0.6):
    """Matte rock: a mottled colour between `dark` and `light`, darker crater pits, deep bump."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.92
    coord = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.6
    noise.inputs["Detail"].default_value = 8.0
    links.new(coord.outputs["Object"], noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.35, (*dark, 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.7, (*light, 1)
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    craters = nodes.new("ShaderNodeTexVoronoi")
    craters.inputs["Scale"].default_value = 0.9
    links.new(coord.outputs["Object"], craters.inputs["Vector"])
    pit = nodes.new("ShaderNodeMapRange")
    pit.inputs["From Min"].default_value = 0.0
    pit.inputs["From Max"].default_value = 0.35
    pit.inputs["To Min"].default_value = 1.0 - pits
    pit.inputs["To Max"].default_value = 1.0
    links.new(craters.outputs["Distance"], pit.inputs["Value"])
    shade = nodes.new("ShaderNodeMix")
    shade.data_type = "RGBA"
    shade.blend_type = "MULTIPLY"
    shade.inputs["Factor"].default_value = 1.0
    links.new(ramp.outputs["Color"], shade.inputs[6])
    links.new(pit.outputs["Result"], shade.inputs[7])
    links.new(shade.outputs[2], bsdf.inputs["Base Color"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    links.new(craters.outputs["Distance"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    mat.diffuse_color = (*light, 1)
    return mat


def cracked(name, light, dark, glow, strength=5.0):
    """Rock with glowing cracks between its plates (magma, void light)."""
    mat = stone(name, light, dark, 0.3)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    coord = nodes.new("ShaderNodeTexCoord")
    cells = nodes.new("ShaderNodeTexVoronoi")
    cells.feature = "DISTANCE_TO_EDGE"
    cells.inputs["Scale"].default_value = 0.42
    cells.inputs["Randomness"].default_value = 1.0
    links.new(coord.outputs["Object"], cells.inputs["Vector"])
    crack = nodes.new("ShaderNodeValToRGB")
    crack.color_ramp.elements[0].position, crack.color_ramp.elements[0].color = 0.0, (*glow, 1)
    crack.color_ramp.elements[1].position, crack.color_ramp.elements[1].color = 0.03, (0, 0, 0, 1)
    links.new(cells.outputs["Distance"], crack.inputs["Fac"])
    links.new(crack.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def gas(name, colour, strength=1.4, density=0.35):
    """A soft glowing cloud: bright in the middle, fading to nothing at its edge."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*colour, 1)
    em.inputs["Strength"].default_value = strength
    facing = nodes.new("ShaderNodeLayerWeight")
    facing.inputs["Blend"].default_value = 0.5
    soft = nodes.new("ShaderNodeMath")
    soft.operation = "POWER"
    soft.inputs[1].default_value = 3.0
    edge = nodes.new("ShaderNodeMath")
    edge.operation = "SUBTRACT"
    edge.inputs[0].default_value = 1.0
    links.new(facing.outputs["Facing"], edge.inputs[1])
    links.new(edge.outputs[0], soft.inputs[0])
    amount = nodes.new("ShaderNodeMath")
    amount.operation = "MULTIPLY"
    amount.inputs[1].default_value = density
    links.new(soft.outputs[0], amount.inputs[0])
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(amount.outputs[0], mix.inputs["Fac"])
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(em.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs[0])
    return mat


# --- Helpers -----------------------------------------------------------------------------------


def rock(location, radius, mat, rough=0.35, squash=(1.0, 1.0, 1.0), seed=0):
    """A lumpy asteroid: an ico sphere, squashed, its surface broken up by noise."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.scale = squash
    obj.rotation_euler = (seed * 0.7, seed * 1.3, seed * 0.4)
    real.shape(obj, 1, radius * rough, radius * 0.9)
    real.assign(obj, mat)
    return obj


def plate(location, size, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = size
    real.assign(obj, mat)
    return obj


def cylinder(location, radius, depth, mat, rotation=(0, 0, 0), vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    for poly in obj.data.polygons:
        poly.use_smooth = True
    real.assign(obj, mat)
    return obj


def torus(location, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=location, rotation=rotation, major_segments=72, minor_segments=16)
    obj = bpy.context.active_object
    for poly in obj.data.polygons:
        poly.use_smooth = True
    real.assign(obj, mat)
    return obj


def spike(base, direction, radius, length, mat):
    """A crystal: a six-sided cone from `base` along `direction`."""
    d = Vector(direction).normalized()
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=radius, radius2=0.0, depth=length, location=Vector(base) + d * length / 2)
    obj = bpy.context.active_object
    obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    real.assign(obj, mat)
    return obj


def egg(location, color, scale=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=location, segments=48, ring_count=24)
    obj = bpy.context.active_object
    obj.scale = (0.8 * scale, 0.8 * scale, 1.05 * scale)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    real.assign(obj, real.jelly("Egg", color, glow=1.6))
    return obj


# Eggs come in three sizes (EggConfig.SIZES; proposed 0.65, 1, 1.5 of the medium one, 2026-11-10);
# the egg's half height at the medium size in these pictures.
EGG_HALF = 1.45


def nest(rock_mat, pad_mat, rim_mat, egg_color, cradle_mat=None, seed=0, at=None, egg_size=1.0):
    """A nest: a flattened rock, a short pillar out of its top and on it a wide landing pad with a
    glowing rim, a cradle in the middle and the egg in it. The pad and the cradle are sized for the
    large egg; any egg rests on the cradle's floor (a small one sits lower in it)."""
    at = at or NEST_AT
    # Not turned: its flat side stays up, under the pad.
    rock(at, 6.0, rock_mat, 0.18, (1.3, 1.15, 0.55), 0)
    top = at + Vector((0, 0, 4.6))
    cylinder(top - Vector((0, 0, 1.4)), 2.0, 2.4, pad_mat)
    cylinder(top, 4.6, 0.5, pad_mat)
    torus(top + Vector((0, 0, 0.25)), 4.6, 0.16, rim_mat)
    torus(top + Vector((0, 0, 0.45)), 1.5 * 1.25, 0.34, cradle_mat or pad_mat)
    floor = top + Vector((0, 0, 0.25))
    egg(floor + Vector((0, 0, EGG_HALF * egg_size)), egg_color, EGG_HALF * egg_size)
    return top


def cloud(centre, size, mat, rng):
    """A soft cloud of gas: a few puffs melted together, smooth, glowing, fading at its edges."""
    puffs = []
    for _ in range(6):
        offset = (rng.uniform(-1, 1) * size * 0.7, rng.uniform(-0.5, 0.5) * size * 0.5, rng.uniform(-0.5, 0.5) * size * 0.5)
        puffs.append((*offset, size * rng.uniform(0.45, 0.75)))
    return real.blob(puffs, mat, tuple(centre), resolution=size * 0.08)


def label(text, location, size=0.9):
    bpy.ops.object.text_add(location=location, rotation=(math.radians(90), 0, 0))
    obj = bpy.context.active_object
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = size
    try:
        obj.data.font = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
    except RuntimeError:
        pass
    real.assign(obj, real.glow("Label", (0.8, 0.85, 1.0), 1.4))


def space(deep, haze):
    """A dark backdrop with stars and a faint haze of the zone's colour."""
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
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.45, (*deep, 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.75, (*haze, 1)
    l.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    stars = n.new("ShaderNodeTexVoronoi")
    stars.inputs["Scale"].default_value = 300.0
    l.new(coord.outputs["Generated"], stars.inputs["Vector"])
    dot = n.new("ShaderNodeMath")
    dot.operation = "LESS_THAN"
    dot.inputs[1].default_value = 0.035
    l.new(stars.outputs["Distance"], dot.inputs[0])
    add = n.new("ShaderNodeMix")
    add.data_type = "RGBA"
    add.blend_type = "ADD"
    add.inputs["Factor"].default_value = 1.0
    l.new(ramp.outputs["Color"], add.inputs[6])
    l.new(dot.outputs[0], add.inputs[7])
    l.new(add.outputs[2], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0


def lights(key_colour, fill_colour, rim_colour):
    scene = bpy.context.scene
    target = Vector((0, 0, 1))
    for name, location, energy, colour, size in (
        ("Key", (-18, -22, 22), 26000, key_colour, 14),
        ("Fill", (24, -16, 4), 7000, fill_colour, 18),
        ("Rim", (0, 26, 14), 22000, rim_colour, 24),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, colour
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)


def render(name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.4
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 30
    cam_data.clip_end = 2000
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (0, -40, 9)
    cam.rotation_euler = (Vector((0, 0, 2.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT_DIR, f"zone_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("Wrote", scene.render.filepath)


# Where things stand in every picture: the nest in the middle, four asteroid kinds round it.
NEST_AT = Vector((0, 0, -3.5))
KINDS_AT = [Vector((-21, 6, 4)), Vector((-12, 12, -9)), Vector((15, 10, -8)), Vector((22, 4, 5))]


# --- Zones ---------------------------------------------------------------------------------------


def debris():
    """The Debris Belt: a scrapyard. Rust and grey rock, wrecked hull plates, girders, beacons."""
    rng = random.Random(1)
    space((0.008, 0.008, 0.02), (0.05, 0.035, 0.03))
    grey = stone("Rock", (0.42, 0.4, 0.44), (0.16, 0.15, 0.17))
    rust = stone("Rust", (0.55, 0.3, 0.16), (0.2, 0.1, 0.06))
    hull = real.armor("Hull", (0.55, 0.58, 0.62))
    hazard = real.glow("Hazard", (1.0, 0.65, 0.1), 3.0)
    beacon = real.glow("Beacon", (1.0, 0.35, 0.15), 8.0)
    teal = real.glow("Teal", (0.2, 0.9, 0.8), 5.0)
    # The nest: a rock with a steel landing plate, amber hazard rim.
    nest(grey, hull, hazard, (0.35, 0.67, 1.0), None, 2)
    # 1: a plain lumpy rock.
    rock(KINDS_AT[0], 4.0, grey, 0.4, (1.0, 0.9, 0.8), 1)
    # 2: rock with a wrecked hull plate and girders sticking out.
    rock(KINDS_AT[1], 3.6, rust, 0.35, (1.2, 1.0, 0.9), 3)
    plate(KINDS_AT[1] + Vector((2.5, 0, 2.5)), (4.0, 0.25, 2.5), hull, (0.3, 0.6, 0.4))
    for i in range(3):
        plate(KINDS_AT[1] + Vector((-1 + i, -1, 3.5)), (0.25, 0.25, 4.0), rust, (0.4 * i, 0.3, 0.2))
    # 3: a cluster of small rocks.
    for i in range(7):
        rock(KINDS_AT[2] + Vector((rng.uniform(-3, 3), rng.uniform(-2, 2), rng.uniform(-2, 2))), rng.uniform(0.8, 1.8), rust if i % 2 else grey, 0.4, (1, 1, 1), i)
    # 4: a wrecked satellite: a hull drum with a dish and a blinking beacon.
    cylinder(KINDS_AT[3], 2.0, 4.5, hull, (0.4, 0.2, 0.8))
    cylinder(KINDS_AT[3] + Vector((0.5, 0, 3.0)), 2.6, 0.3, hull, (0.7, 0, 0.3))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.35, location=KINDS_AT[3] + Vector((-1.5, -1.5, 2.5)))
    real.assign(bpy.context.active_object, beacon)
    # Dressing: floating girders and scrap, little teal lights.
    for i in range(14):
        p = Vector((rng.uniform(-30, 30), rng.uniform(-6, 26), rng.uniform(-10, 14)))
        plate(p, (rng.uniform(0.2, 0.4), rng.uniform(0.2, 0.4), rng.uniform(1.5, 4.0)), rust if i % 3 else hull, (rng.uniform(0, 3), rng.uniform(0, 3), 0))
        if i % 4 == 0:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2, location=p + Vector((0, 0, 0.6)))
            real.assign(bpy.context.active_object, teal)
    label("Пояс обломков", Vector((0, -8, 12.5)), 1.3)
    lights((1.0, 0.92, 0.8), (0.8, 0.85, 1.0), (1.0, 0.7, 0.45))


def ice():
    """The Ice Rings: frost-white and blue. Snowy rocks, clear ice chunks, crystal clusters and a
    glittering band of flat shards."""
    rng = random.Random(2)
    space((0.006, 0.012, 0.03), (0.04, 0.08, 0.12))
    snow = stone("Snow", (0.92, 0.96, 1.0), (0.6, 0.72, 0.85), 0.3)
    blue = real.frost("BlueIce", (0.45, 0.72, 0.95))
    clear = real.crystal("ClearIce", (0.7, 0.9, 1.0), 0.2)
    crystal = real.crystal("Crystal", (0.55, 0.85, 1.0), 1.2)
    rim = real.glow("IceRim", (0.6, 0.95, 1.0), 4.0)
    # The nest: a blue ice rock with a frozen pad ringed with crystals.
    top = nest(blue, snow, rim, (0.78, 0.35, 1.0), clear, 4)
    for i in range(7):
        angle = i / 7 * math.tau
        spike(top + Vector((math.cos(angle) * 4.4, math.sin(angle) * 4.4, 0)), (math.cos(angle) * 0.4, math.sin(angle) * 0.4, 1), 0.35, rng.uniform(1.0, 2.2), crystal)
    # 1: a snowy rock.
    rock(KINDS_AT[0], 4.0, snow, 0.35, (1.0, 0.95, 0.8), 1)
    # 2: a clear ice chunk, faceted.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=3.4, location=KINDS_AT[1])
    real.assign(bpy.context.active_object, clear)
    # 3: a crystal cluster on a small rock.
    rock(KINDS_AT[2], 2.4, blue, 0.3, (1.2, 1, 0.8), 5)
    for i in range(9):
        direction = (rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.2, 1))
        spike(KINDS_AT[2] + Vector((0, 0, 1.2)), direction, rng.uniform(0.35, 0.6), rng.uniform(2.0, 4.5), crystal)
    # 4: a long icy rock with a frost band.
    rock(KINDS_AT[3], 3.4, blue, 0.25, (1.6, 0.9, 0.8), 6)
    torus(KINDS_AT[3], 4.2, 0.18, rim, (0.3, 0.5, 0))
    # Dressing: a band of glittering flat shards across the picture, like a planet's ring.
    for i in range(70):
        x = rng.uniform(-36, 36)
        p = Vector((x, rng.uniform(0, 30), 9 + x * 0.12 + rng.uniform(-1.2, 1.2)))
        plate(p, (rng.uniform(0.4, 1.4), rng.uniform(0.4, 1.0), 0.08), clear if i % 3 else snow, (rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3)))
    label("Ледяные кольца", Vector((0, -8, 12.5)), 1.3)
    lights((0.92, 0.96, 1.0), (0.6, 0.8, 1.0), (0.7, 0.9, 1.0))


def nebula():
    """The Red Nebula: warm gas. Basalt with glowing magma veins, pumice-red rock, rocks wrapped in
    glowing pink gas, ember crystals; soft clouds drift through."""
    rng = random.Random(3)
    space((0.03, 0.005, 0.015), (0.22, 0.04, 0.08))
    basalt = cracked("Basalt", (0.2, 0.12, 0.11), (0.06, 0.04, 0.04), (1.0, 0.3, 0.06), 3.0)
    pumice = stone("Pumice", (0.6, 0.24, 0.18), (0.25, 0.08, 0.07), 0.8)
    dark = stone("DarkRock", (0.22, 0.13, 0.14), (0.08, 0.05, 0.06))
    ember = real.crystal("Ember", (1.0, 0.45, 0.2), 2.5)
    rim = real.glow("LavaRim", (1.0, 0.4, 0.15), 5.0)
    gas_pink = gas("PinkGas", (1.0, 0.3, 0.5))
    gas_red = gas("RedGas", (0.95, 0.2, 0.15))
    gas_violet = gas("VioletGas", (0.6, 0.25, 0.9))
    # The nest: magma-cracked basalt with an obsidian pad and a lava rim.
    nest(basalt, dark, rim, (1.0, 0.78, 0.24), None, 7)
    # 1: magma-veined basalt.
    rock(KINDS_AT[0], 4.0, basalt, 0.4, (1.0, 0.9, 0.85), 1)
    # 2: pumice-red rock with holes (lumpy).
    rock(KINDS_AT[1], 3.6, pumice, 0.55, (1.1, 1.0, 0.9), 2)
    # 3: a rock wrapped in a glowing gas cloud.
    rock(KINDS_AT[2], 2.8, dark, 0.35, (1, 1, 1), 3)
    cloud(KINDS_AT[2], 4.5, gas_pink, rng)
    # 4: ember crystals growing from a dark rock.
    rock(KINDS_AT[3], 2.8, dark, 0.3, (1.2, 1, 0.9), 4)
    for i in range(6):
        spike(KINDS_AT[3] + Vector((0, 0, 1.0)), (rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.3, 1)), 0.45, rng.uniform(2.0, 3.6), ember)
    # Dressing: big soft gas clouds in reds, pinks and violet, floating sparks.
    for i in range(9):
        centre = Vector((rng.uniform(-40, 40), rng.uniform(14, 40), rng.uniform(-12, 16)))
        cloud(centre, rng.uniform(6, 11), (gas_pink, gas_red, gas_violet)[i % 3], rng)
    for i in range(30):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(rng.uniform(-30, 30), rng.uniform(-8, 20), rng.uniform(-8, 14)))
        real.assign(bpy.context.active_object, rim)
    label("Красная туманность", Vector((0, -8, 12.5)), 1.3)
    lights((1.0, 0.85, 0.75), (1.0, 0.5, 0.55), (1.0, 0.45, 0.3))


def horizon():
    """The Event Horizon: the dark edge. Black-violet rock with violet crystal veins, rocks pulled
    into streaks, floating violet crystals, rocks inside thin gravity rings; the black hole far off."""
    rng = random.Random(4)
    space((0.008, 0.004, 0.02), (0.09, 0.03, 0.16))
    void = cracked("Void", (0.16, 0.13, 0.22), (0.04, 0.03, 0.06), (0.6, 0.25, 1.0), 3.5)
    dark = stone("DarkRock", (0.18, 0.16, 0.24), (0.05, 0.04, 0.07))
    violet = real.crystal("Violet", (0.65, 0.35, 1.0), 2.0)
    rim = real.glow("VoidRim", (0.75, 0.45, 1.0), 5.0)
    ring = real.glow("GravityRing", (0.55, 0.75, 1.0), 4.0)
    disc = real.glow("Accretion", (1.0, 0.6, 0.25), 6.0)
    # The nest: void rock, dark pad, violet rim.
    nest(void, dark, rim, (0.35, 0.67, 1.0), None, 8)
    # 1: void rock with violet veins.
    rock(KINDS_AT[0], 4.0, void, 0.4, (1.0, 0.9, 0.85), 1)
    # 2: a rock pulled into a long streak (stretched by the hole).
    rock(KINDS_AT[1], 2.6, dark, 0.3, (2.6, 0.7, 0.7), 2)
    # 3: floating violet crystals.
    for i in range(5):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=rng.uniform(0.8, 1.6), location=KINDS_AT[2] + Vector((rng.uniform(-3, 3), rng.uniform(-2, 2), rng.uniform(-2, 3))))
        obj = bpy.context.active_object
        obj.scale = (0.6, 0.6, 1.6)
        obj.rotation_euler = (rng.uniform(0, 1), rng.uniform(0, 1), 0)
        real.assign(obj, violet)
    # 4: a rock inside a thin glowing gravity ring.
    rock(KINDS_AT[3], 2.8, void, 0.3, (1, 1, 1), 4)
    torus(KINDS_AT[3], 4.8, 0.12, ring, (1.1, 0.3, 0))
    # Dressing: the black hole far behind, with its glowing disc.
    hole_at = Vector((-8, 140, 30))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=14, location=hole_at)
    real.assign(bpy.context.active_object, real.glow("Hole", (0, 0, 0), 0.0))
    torus(hole_at, 26, 4.0, disc, (1.25, 0.15, 0))
    torus(hole_at, 15, 0.8, real.glow("PhotonRing", (1.0, 0.85, 0.6), 8.0), (math.radians(90), 0, 0))
    for i in range(24):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.1, location=(rng.uniform(-30, 30), rng.uniform(-8, 20), rng.uniform(-8, 14)))
        real.assign(bpy.context.active_object, rim)
    label("Горизонт событий", Vector((0, -8, 12.5)), 1.3)
    lights((0.85, 0.8, 1.0), (0.6, 0.5, 1.0), (0.8, 0.55, 1.0))


def sizes():
    """The same nest with a small, a medium and a large egg side by side."""
    space((0.008, 0.008, 0.02), (0.05, 0.035, 0.03))
    grey = stone("Rock", (0.42, 0.4, 0.44), (0.16, 0.15, 0.17))
    hull = real.armor("Hull", (0.55, 0.58, 0.62))
    hazard = real.glow("Hazard", (1.0, 0.65, 0.1), 3.0)
    for x, size, word in ((-17, 0.65, "маленькое"), (0, 1.0, "среднее"), (17, 1.5, "большое")):
        nest(grey, hull, hazard, (0.35, 0.67, 1.0), None, 0, Vector((x, 0, -3.5)), size)
        label(word, Vector((x, -8, -7)), 1.1)
    label("Гнездо и размеры яиц", Vector((0, -8, 12.5)), 1.3)
    lights((1.0, 0.92, 0.8), (0.8, 0.85, 1.0), (1.0, 0.7, 0.45))


BUILDERS = {"debris": debris, "ice": ice, "nebula": nebula, "horizon": horizon, "sizes": sizes}

for zone in ZONES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    BUILDERS[zone]()
    render(zone)
