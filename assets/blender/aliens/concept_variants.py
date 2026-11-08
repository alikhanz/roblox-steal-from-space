# Three design approaches for the aliens after the user's review of the tier ladder
# (2026-11-08: "I like the style, but it looks ugly — more options"). Each is shown as close-up
# beauty shots: a crab and a slime in the common tier, and the slime as a legendary.
#   1. "Cartoon realism" — smooth subdivided forms, glowing skin, big expressive eyes with iris,
#      pupil and catch-light, like animated films.
#   2. "Sleek sci-fi" — robot pets: ceramic shells, a dark visor with glowing eyes, light seams.
#   3. "Deep space" — translucent glowing creatures like deep-sea life: glowing organs inside,
#      tentacles, shimmer.
#
# Run headless from the repo root (writes one PNG per shot into <out dir>):
#   blender --background --factory-startup --python assets/blender/aliens/concept_variants.py -- <out dir>

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))

import bpy  # noqa: E402
import real  # noqa: E402
from mathutils import Vector  # noqa: E402

OUT_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "variants"
GOLD = (1.0, 0.72, 0.18)


# --- Geometry -----------------------------------------------------------------------------------


def smooth(obj, levels=2):
    mod = obj.modifiers.new("Subdivision", "SUBSURF")
    mod.levels = mod.render_levels = levels
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def sphere(location, scale, mat, segments=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=location)
    obj = bpy.context.active_object
    obj.scale = scale
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return real.assign(obj, mat)


def cone(location, radius, depth, mat, rotation=(0, 0, 0), vertices=24, radius2=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius2, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return real.assign(obj, mat)


def cylinder(location, radius, depth, mat, rotation=(0, 0, 0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return real.assign(obj, mat)


def torus(location, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=location, major_radius=major, minor_radius=minor, rotation=rotation, major_segments=64, minor_segments=16)
    obj = bpy.context.active_object
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return real.assign(obj, mat)


def rounded_box(location, size, mat, bevel=0.3, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, scale=size, rotation=rotation)
    obj = bpy.context.active_object
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 6
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.shade_smooth() if hasattr(obj.data, "shade_smooth") else None
    return real.assign(obj, mat)


def teardrop(location, radius, height, mat, pinch=0.85, sag=0.15, segments=48):
    """A drop: round below, drawn up to a soft point above, the bottom spread a little."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=location, radius=radius)
    obj = bpy.context.active_object
    for vertex in obj.data.vertices:
        h = vertex.co.z / radius
        if h > 0:
            factor = 1 - pinch * h ** 2.2
            vertex.co.x *= factor
            vertex.co.y *= factor
            vertex.co.z *= height
        else:
            vertex.co.x *= 1 + sag * (-h)
            vertex.co.y *= 1 + sag * (-h)
            vertex.co.z *= 0.75
    return smooth(real.assign(obj, mat), 1)


# --- Eyes ---------------------------------------------------------------------------------------


def film_eye(location, size, iris_color, look=(0, -1, 0)):
    """An animated-film eye: white, a coloured iris, a black pupil, a clear cornea with a catch-light."""
    x, y, z = location
    sphere((x, y, z), (size, size, size), real.jelly("Sclera", (0.95, 0.95, 0.97)), 32)
    front = y - size * 0.92
    cylinder((x, front, z), size * 0.55, size * 0.06, real.iridescent("Iris", iris_color, glow=0.5), (math.radians(90), 0, 0), 32)
    cylinder((x, front - size * 0.04, z), size * 0.27, size * 0.05, real.gloss("Pupil", (0.0, 0.0, 0.0)), (math.radians(90), 0, 0), 32)
    sphere((x, y - size * 0.05, z), (size * 1.03, size * 1.03, size * 1.03), real.crystal("Cornea", (1, 1, 1)), 32)
    sphere((x - size * 0.25, front - size * 0.1, z + size * 0.28), (size * 0.12, size * 0.04, size * 0.12), real.glow("Catchlight", (1, 1, 1), 6.0), 16)


def visor(location, width, height, mat_glass, eye_color):
    """A robot pet's dark visor with two glowing eye shapes."""
    x, y, z = location
    rounded_box((x, y, z), (width, 0.08, height), mat_glass, bevel=min(width, height) * 0.8)
    for side in (-1, 1):
        sphere((x + side * width * 0.42, y - 0.09, z + height * 0.05), (width * 0.17, 0.02, height * 0.45), real.glow("EyeLight", eye_color, 9.0), 24)


# --- 1. Cartoon realism -------------------------------------------------------------------------


def cartoon_slime(legendary):
    color = (0.22, 0.85, 0.45)
    body = teardrop((0, 0, 0.9), 0.95, 1.25, real.jelly("Jelly", color, 0.08))
    for side in (-1, 1):
        film_eye((side * 0.33, -0.66, 1.08), 0.2, (0.2, 0.75, 0.3))
    mouth = torus((0, -0.86, 0.75), 0.09, 0.025, real.gloss("Mouth", (0.05, 0.15, 0.08)), (math.radians(90), 0, 0))
    for vertex in mouth.data.vertices:
        if vertex.co.y > 0:
            vertex.co.y = 0
    if legendary:
        real.assign(body, real.iridescent("Opal", (0.55, 1.0, 0.7), transmission=0.4, glow=0.35))
        crown(0, 0, 2.05, 0.9)
        aura(body, GOLD)
        sparkles(GOLD, 14, 1.5)
    return body


def cartoon_crab(legendary=False):
    color = (0.95, 0.42, 0.25)
    shell = real.jelly("Shell", color, 0.0)
    real_shell = real.jelly("Shell", color, 0.0)
    body = sphere((0, 0, 0.8), (1.05, 0.82, 0.55), real_shell, 48)
    smooth(body, 1)
    limb = real.jelly("Limb", (1.0, 0.55, 0.35), 0.0)
    for side in (-1, 1):
        cylinder((side * 0.3, -0.35, 1.3), 0.06, 0.5, limb)
        film_eye((side * 0.3, -0.42, 1.62), 0.17, (0.9, 0.6, 0.2))
        arm = cylinder((side * 1.05, -0.45, 0.88), 0.12, 0.55, limb, (0, math.radians(side * 55), math.radians(side * 30)))
        smooth(arm, 1)
        claw = sphere((side * 1.35, -0.75, 1.05), (0.34, 0.28, 0.3), real_shell, 32)
        cone((side * 1.42, -1.08, 1.12), 0.11, 0.42, limb, (math.radians(95), 0, math.radians(side * 10)))
        cone((side * 1.3, -1.02, 0.95), 0.08, 0.32, limb, (math.radians(105), 0, math.radians(side * -10)))
        for index, y in enumerate((0.35, 0.1, -0.15)):
            leg = cylinder((side * 0.95, y, 0.45), 0.07, 0.6, limb, (0, math.radians(side * 40), 0))
            smooth(leg, 1)
    return body


# --- 2. Sleek sci-fi ----------------------------------------------------------------------------


def ceramic(color):
    return real.gloss("Ceramic", color, 0.18)


def scifi_slime(legendary):
    accent = (0.2, 0.95, 0.6)
    base_mat = real.chrome("Base", GOLD) if legendary else ceramic((0.92, 0.94, 0.97))
    base = cylinder((0, 0, 0.25), 0.75, 0.4, base_mat, vertices=48)
    smooth(base, 1)
    torus((0, 0, 0.47), 0.72, 0.035, real.glow("Seam", accent, 6.0))
    # Living slime inside a glass dome on the base.
    teardrop((0, 0, 0.95), 0.6, 1.2, real.jelly("Slime", accent, 0.6))
    sphere((0, 0, 1.0), (0.78, 0.78, 0.9), real.crystal("Dome", (0.9, 0.97, 1.0)), 48)
    visor((0, -0.72, 1.0), 0.42, 0.18, real.gloss("Visor", (0.02, 0.03, 0.05), 0.05), accent)
    for side in (-1, 1):
        rounded_box((side * 0.55, -0.15, 0.1), (0.18, 0.28, 0.1), base_mat, bevel=0.08)
    if legendary:
        torus((0, 0, 2.0), 0.4, 0.04, real.glow("Halo", GOLD, 10.0), (math.radians(15), 0, 0))
        cone((0, 0, 1.92), 0.04, 0.12, base_mat)
        sparkles(GOLD, 10, 1.4)
        aura_ring(GOLD)


def scifi_crab(legendary=False):
    accent = (1.0, 0.55, 0.2)
    shell_mat = ceramic((0.92, 0.94, 0.97))
    dark = real.gloss("Joint", (0.1, 0.11, 0.13), 0.25)
    shell = rounded_box((0, 0, 0.85), (0.9, 0.65, 0.34), shell_mat, bevel=0.33)
    rounded_box((0, 0.05, 1.18), (0.6, 0.45, 0.08), ceramic((1.0, 0.55, 0.2)), bevel=0.07)
    visor((0, -0.66, 0.9), 0.55, 0.13, real.gloss("Visor", (0.02, 0.03, 0.05), 0.05), (0.3, 0.9, 1.0))
    for side in (-1, 1):
        for y in (0.35, 0.05, -0.25):
            sphere((side * 0.95, y, 0.75), (0.1, 0.1, 0.1), dark, 16)
            cylinder((side * 1.15, y, 0.5), 0.05, 0.55, shell_mat, (0, math.radians(side * 35), 0))
            sphere((side * 1.3, y, 0.22), (0.07, 0.07, 0.07), real.glow("Foot", accent, 6.0), 12)
        sphere((side * 1.0, -0.45, 0.85), (0.11, 0.11, 0.11), dark, 16)
        claw = rounded_box((side * 1.3, -0.75, 1.0), (0.22, 0.3, 0.2), shell_mat, bevel=0.15, rotation=(0, 0, math.radians(side * 20)))
        rounded_box((side * 1.36, -1.05, 1.12), (0.08, 0.16, 0.06), shell_mat, bevel=0.05)
        rounded_box((side * 1.28, -1.03, 0.9), (0.07, 0.14, 0.05), shell_mat, bevel=0.04)
        torus((side * 1.3, -0.75, 1.0), 0.18, 0.02, real.glow("Seam", accent, 6.0), (math.radians(90), 0, math.radians(side * 20)))
    torus((0, 0, 0.85), 0.92, 0.02, real.glow("Seam", accent, 5.0))
    return shell


# --- 3. Deep space ------------------------------------------------------------------------------


def deep_slime(legendary):
    color = (0.25, 0.8, 1.0) if not legendary else (0.95, 0.6, 1.0)
    bell = teardrop((0, 0, 1.15), 0.85, 0.95, real.jelly("Bell", color, 0.15, clear=True), pinch=0.35, sag=0.0)
    # Glowing organs inside.
    sphere((0, 0, 1.1), (0.32, 0.32, 0.36), real.glow("Core", lighter(color, 0.4), 9.0), 32)
    for dx, dz in ((-0.3, 0.9), (0.32, 0.92), (0.0, 1.45)):
        sphere((dx, -0.05, dz), (0.1, 0.1, 0.1), real.glow("Organ", color, 6.0), 16)
    # Short trailing tentacles below.
    count = 7 if not legendary else 11
    for index in range(count):
        angle = index / count * math.tau
        x, y = math.cos(angle) * 0.55, math.sin(angle) * 0.45
        tentacle = cone((x, y, 0.35), 0.07, 0.75, real.jelly("Tentacle", color, 0.6, clear=True), (math.radians(8 * math.sin(angle)), math.radians(8 * math.cos(angle)), 0), 12)
        sphere((x * 1.05, y * 1.05, -0.05), (0.04, 0.04, 0.04), real.glow("Tip", lighter(color, 0.5), 10.0), 10)
    for side in (-1, 1):
        sphere((side * 0.28, -0.72, 1.15), (0.09, 0.05, 0.11), real.glow("Eye", (1.0, 1.0, 1.0), 12.0), 16)
    if legendary:
        sparkles((1.0, 0.85, 0.5), 18, 1.6)
        aura(bell, (1.0, 0.7, 1.0))
        torus((0, 0, 2.15), 0.35, 0.03, real.glow("Halo", GOLD, 10.0), (math.radians(15), 0, 0))


def deep_crab(legendary=False):
    color = (0.35, 0.6, 1.0)
    shell_mat = real.jelly("Shell", color, 0.1, clear=True)
    body = sphere((0, 0, 0.8), (1.0, 0.78, 0.5), shell_mat, 48)
    smooth(body, 1)
    # Visible glowing insides.
    sphere((0, 0.05, 0.8), (0.45, 0.35, 0.22), real.glow("Heart", (0.4, 1.0, 0.9), 8.0), 24)
    for dx in (-0.45, 0.45):
        sphere((dx, 0.1, 0.78), (0.15, 0.12, 0.1), real.glow("Organ", (0.9, 0.5, 1.0), 6.0), 16)
    limb = real.jelly("Limb", lighter(color, 0.2), 0.3, clear=True)
    for side in (-1, 1):
        cylinder((side * 0.28, -0.35, 1.2), 0.05, 0.45, limb)
        sphere((side * 0.28, -0.4, 1.48), (0.11, 0.1, 0.12), real.glow("Eye", (1.0, 1.0, 1.0), 12.0), 16)
        claw = sphere((side * 1.3, -0.7, 1.0), (0.3, 0.24, 0.26), shell_mat, 32)
        sphere((side * 1.3, -0.7, 1.0), (0.12, 0.1, 0.1), real.glow("ClawGlow", (0.4, 1.0, 0.9), 6.0), 12)
        cylinder((side * 1.0, -0.4, 0.88), 0.09, 0.55, limb, (0, math.radians(side * 55), math.radians(side * 30)))
        for y in (0.35, 0.05, -0.25):
            cylinder((side * 1.05, y, 0.45), 0.05, 0.7, limb, (0, math.radians(side * 40), 0))
            sphere((side * 1.27, y, 0.13), (0.045, 0.045, 0.045), real.glow("Tip", (0.4, 1.0, 0.9), 10.0), 10)
    return body


# --- Shared tier effects ------------------------------------------------------------------------


def lighter(color, amount=0.45):
    return tuple(c + (1 - c) * amount for c in color)


def crown(x, y, z, scale):
    gold = real.chrome("Gold", GOLD)
    cylinder((x, y, z), 0.32 * scale, 0.12 * scale, gold, vertices=32)
    for index in range(6):
        angle = index / 6 * math.tau
        cone((x + math.cos(angle) * 0.28 * scale, y + math.sin(angle) * 0.28 * scale, z + 0.17 * scale), 0.07 * scale, 0.24 * scale, gold, vertices=12)
    sphere((x, y - 0.32 * scale, z), (0.07, 0.04, 0.07), real.glow("Gem", (1.0, 0.2, 0.4), 6.0), 16)


def aura(body, color):
    shell = body.copy()
    shell.data = body.data.copy()
    shell.scale = tuple(s * 1.12 for s in body.scale)
    bpy.context.scene.collection.objects.link(shell)
    real.assign(shell, real.aura("Aura", color, 2.5, 0.12))


def aura_ring(color):
    for index in range(16):
        angle = index / 16 * math.tau
        sphere((math.cos(angle) * 1.25, math.sin(angle) * 0.8, 0.9 + 0.3 * math.sin(angle * 2)), (0.04, 0.04, 0.04), real.glow("Mote", color, 10.0), 10)


def sparkles(color, count, radius):
    mat = real.glow("Sparkle", color, 12.0)
    for index in range(count):
        angle = index * 2.39996
        height = 0.4 + (index * 0.37) % 1.8
        r = radius * (0.85 + 0.15 * math.sin(index))
        sphere((math.cos(angle) * r, math.sin(angle) * r * 0.7, height), (0.035, 0.035, 0.035), mat, 10)


# --- Studio -------------------------------------------------------------------------------------


def studio(rim_color):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x = scene.render.resolution_y = 900
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    dark = nodes.get("Background")
    dark.inputs["Color"].default_value = (0.006, 0.008, 0.025, 1.0)
    sky = nodes.new("ShaderNodeBackground")
    sky.inputs["Color"].default_value = (0.25, 0.35, 0.6, 1.0)
    sky.inputs["Strength"].default_value = 1.2
    path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(sky.outputs["Background"], mix.inputs[1])
    links.new(dark.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], nodes.get("World Output").inputs["Surface"])
    # A dark glossy floor to catch reflections and glow.
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    real.assign(bpy.context.active_object, real.gloss("Floor", (0.015, 0.018, 0.035), 0.6))
    target = Vector((0, 0, 0.85))

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        # Only the key light leaves highlights: the others would mirror as bright squares in the
        # glossy floor in front of the creature.
        if name != "Key":
            data.specular_factor = 0.0
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (-3.5, -4.5, 4.5), 650, 3, (1.0, 0.97, 0.92))
    area("Fill", (4.5, -3.5, 1.5), 150, 4, (0.75, 0.85, 1.0))
    area("Rim", (1.5, 4.5, 3.5), 900, 3, rim_color)
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 60
    camera_data.dof.use_dof = True
    camera_data.dof.focus_distance = 7.5
    camera_data.dof.aperture_fstop = 5.6
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = (-3.6, -8.0, 2.7)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera


SHOTS = [
    ("1-cartoon-crab", lambda: cartoon_crab(), (1.0, 0.6, 0.4)),
    ("1-cartoon-slime", lambda: cartoon_slime(False), (0.5, 1.0, 0.6)),
    ("1-cartoon-slime-legendary", lambda: cartoon_slime(True), GOLD),
    ("2-scifi-crab", lambda: scifi_crab(), (0.4, 0.8, 1.0)),
    ("2-scifi-slime", lambda: scifi_slime(False), (0.4, 1.0, 0.7)),
    ("2-scifi-slime-legendary", lambda: scifi_slime(True), GOLD),
    ("3-deep-crab", lambda: deep_crab(), (0.4, 0.7, 1.0)),
    ("3-deep-slime", lambda: deep_slime(False), (0.3, 0.8, 1.0)),
    ("3-deep-slime-legendary", lambda: deep_slime(True), (1.0, 0.6, 1.0)),
]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    only = os.environ.get("SHOT")
    for name, make, rim in SHOTS:
        if only and only != name:
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        make()
        studio(rim)
        bpy.context.scene.render.filepath = os.path.join(OUT_DIR, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("Wrote", name)


main()
