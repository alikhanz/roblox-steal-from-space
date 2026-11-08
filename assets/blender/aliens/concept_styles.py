# Style options for the aliens after the user's review (2026-11-08): "too cartoony — more
# realistic and closer to space; a crystal worm should be crystal". Three directions on the same
# three babies (slime, crab, crystal worm), one row each:
#   1. Living aliens  — translucent jelly, alien chitin, bioluminescent spots, dark wet eyes.
#   2. Cosmic matter  — bodies of nebula with stars inside, glowing rims.
#   3. Biotech        — living bodies with armour plates, light panels and antennae.
# The crystal worm is clear faceted crystal in every row.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/concept_styles.py -- <out.png>

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))

import bpy  # noqa: E402
import real  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "concept_styles.png"
SPACING = 4.6
ROW_HEIGHT = 3.9
YAW = -24

SLIME = (0.25, 0.85, 0.45)
CRAB = (0.22, 0.55, 0.62)
CRAB_DARK = (0.05, 0.12, 0.18)
ICE = (0.72, 0.9, 1.0)
EYE = (0.01, 0.01, 0.02)


def new_objects(make):
    before = set(bpy.data.objects)
    make()
    return set(bpy.data.objects) - before


def turn(objects, x, z, degrees):
    bpy.context.view_layer.update()
    pivot = Matrix.Translation(Vector((x, 0, z)))
    rotation = pivot @ Matrix.Rotation(math.radians(degrees), 4, "Z") @ pivot.inverted()
    for obj in objects:
        obj.matrix_world = rotation @ obj.matrix_world


def uv_sphere(location, scale, mat, segments=48):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=location)
    obj = bpy.context.active_object
    obj.scale = scale
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return real.assign(obj, mat)


def ico(location, scale, mat, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, location=location)
    obj = bpy.context.active_object
    obj.scale = scale
    return real.assign(obj, mat)


def cone(location, radius, depth, mat, rotation=(0, 0, 0), vertices=8, radius2=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius2, depth=depth, location=location, rotation=rotation)
    return real.assign(bpy.context.active_object, mat)


def cylinder(location, radius, depth, mat, rotation=(0, 0, 0), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return real.assign(obj, mat)


def alien_eye(location, size, iris_color):
    """A dark wet alien eye with a glowing ring of iris."""
    uv_sphere(location, (size, size * 0.8, size), real.gloss("Eye", EYE), 32)
    x, y, z = location
    bpy.ops.mesh.primitive_torus_add(location=(x, y - size * 0.72, z), major_radius=size * 0.48, minor_radius=size * 0.09, rotation=(math.radians(90), 0, 0))
    real.assign(bpy.context.active_object, real.glow("Iris", iris_color, 6.0))


# --- Slimes -------------------------------------------------------------------------------------


def slime_living(x, z):
    body = uv_sphere((x, 0, z + 0.85), (1.05, 0.95, 0.82), real.jelly("Jelly", SLIME, 0.15), 64)
    real.shape(body, 1, 0.07, 1.6)
    uv_sphere((x, 0.05, z + 0.8), (0.35, 0.35, 0.35), real.glow("Core", (0.6, 1.0, 0.5), 8.0), 32)
    for dx in (-0.32, 0.0, 0.32):
        alien_eye((x + dx, -0.78, z + 1.15 + (0.08 if dx == 0 else 0)), 0.13, (0.7, 1.0, 0.4))
    for dx, dz in ((-0.7, 0.55), (0.75, 0.6), (-0.4, 1.4), (0.5, 1.35)):
        uv_sphere((x + dx, -0.62, z + dz), (0.06, 0.04, 0.06), real.glow("Spot", (0.5, 1.0, 0.6), 5.0), 12)


def slime_cosmic(x, z):
    body = uv_sphere((x, 0, z + 0.85), (1.05, 0.95, 0.82), real.nebula("Nebula", (0.05, 0.02, 0.15), (0.25, 0.12, 0.55), (0.3, 0.85, 0.9)), 64)
    real.shape(body, 1, 0.05, 1.6)
    for dx in (-0.3, 0.3):
        alien_eye((x + dx, -0.8, z + 1.1), 0.15, (0.6, 0.95, 1.0))
    bpy.ops.mesh.primitive_torus_add(location=(x, 0, z + 0.9), major_radius=1.35, minor_radius=0.02, rotation=(math.radians(75), 0, math.radians(20)))
    real.assign(bpy.context.active_object, real.glow("Halo", (0.6, 0.85, 1.0), 4.0))


def slime_biotech(x, z):
    body = uv_sphere((x, 0, z + 0.85), (1.05, 0.95, 0.82), real.jelly("Jelly", SLIME, 0.1), 64)
    real.shape(body, 1, 0.05, 1.6)
    plate = uv_sphere((x, 0.15, z + 1.35), (0.8, 0.7, 0.32), real.armor("Plate", (0.55, 0.6, 0.66)), 32)
    plate.rotation_euler = (math.radians(-15), 0, 0)
    cylinder((x + 0.35, 0.2, z + 1.85), 0.025, 0.6, real.armor("Antenna", (0.4, 0.42, 0.46)))
    uv_sphere((x + 0.35, 0.2, z + 2.17), (0.06, 0.06, 0.06), real.glow("Beacon", (1.0, 0.3, 0.2), 8.0), 12)
    alien_eye((x, -0.8, z + 1.05), 0.2, (0.3, 0.9, 1.0))
    for dx in (-0.6, 0.6):
        bpy.ops.mesh.primitive_cube_add(location=(x + dx, -0.7, z + 0.65), scale=(0.12, 0.02, 0.05))
        real.assign(bpy.context.active_object, real.glow("Panel", (0.3, 0.9, 1.0), 5.0))


# --- Crabs --------------------------------------------------------------------------------------


def crab_body(x, z, shell_mat, limb_mat, iris):
    shell = uv_sphere((x, 0, z + 0.8), (1.15, 0.85, 0.5), shell_mat, 48)
    real.shape(shell, 1, 0.12, 2.0)
    for side in (-1, 1):
        # Eyes on stalks.
        cylinder((x + side * 0.28, -0.45, z + 1.3), 0.05, 0.5, limb_mat)
        alien_eye((x + side * 0.28, -0.5, z + 1.6), 0.12, iris)
        # Claws: an arm and a pointed pincer pair.
        arm = cylinder((x + side * 1.2, -0.25, z + 0.85), 0.11, 0.7, limb_mat, (0, math.radians(side * 60), math.radians(side * 20)))
        claw = uv_sphere((x + side * 1.55, -0.55, z + 1.12), (0.28, 0.2, 0.38), limb_mat, 24)
        claw.rotation_euler = (0, math.radians(side * -20), 0)
        cone((x + side * 1.62, -0.6, z + 1.55), 0.1, 0.42, limb_mat, (0, math.radians(side * -15), 0), 8)
        cone((x + side * 1.42, -0.62, z + 1.5), 0.07, 0.3, limb_mat, (0, math.radians(side * 15), 0), 8)
        # Four jointed legs.
        for index in range(4):
            leg_x = x + side * (0.85 + index * 0.05)
            leg_y = 0.35 - index * 0.25
            cylinder((leg_x + side * 0.15, leg_y, z + 0.55), 0.05, 0.5, limb_mat, (0, math.radians(side * 70), 0))
            cone((leg_x + side * 0.42, leg_y, z + 0.25), 0.05, 0.55, limb_mat, (0, math.radians(side * -20), 0), 8)
    return shell


def crab_living(x, z):
    crab_body(x, z, real.chitin("Chitin", CRAB, CRAB_DARK), real.chitin("Limb", (0.18, 0.42, 0.5), CRAB_DARK), (0.4, 1.0, 0.8))
    for dx, dy in ((-0.5, 0.0), (0.0, 0.2), (0.5, 0.0), (-0.25, -0.35), (0.25, -0.35)):
        uv_sphere((x + dx, dy - 0.2, z + 1.25), (0.07, 0.07, 0.04), real.glow("Spot", (0.4, 1.0, 0.85), 5.0), 12)


def crab_cosmic(x, z):
    space = real.nebula("Nebula", (0.02, 0.03, 0.12), (0.12, 0.25, 0.6), (0.85, 0.5, 0.95))
    crab_body(x, z, space, space, (0.85, 0.6, 1.0))


def crab_biotech(x, z):
    crab_body(x, z, real.armor("Armor", (0.35, 0.4, 0.46)), real.chitin("Limb", CRAB, CRAB_DARK, 0.5), (1.0, 0.6, 0.2))
    for dx in (-0.45, 0.0, 0.45):
        bpy.ops.mesh.primitive_cube_add(location=(x + dx, -0.62, z + 0.85), scale=(0.14, 0.02, 0.04))
        real.assign(bpy.context.active_object, real.glow("Panel", (1.0, 0.6, 0.2), 6.0))
    cylinder((x, 0.2, z + 1.5), 0.03, 0.7, real.armor("Mast", (0.4, 0.42, 0.46)))
    for spin in (0, 90):
        bpy.ops.mesh.primitive_cube_add(location=(x, 0.2, z + 1.86), scale=(0.55, 0.05, 0.01), rotation=(0, 0, math.radians(spin + 25)))
        real.assign(bpy.context.active_object, real.armor("Rotor", (0.7, 0.72, 0.76)))


# --- Crystal worm -------------------------------------------------------------------------------


def crystal_worm(x, z, core_color, extra=None):
    """Clear faceted crystal segments with a glowing core running through them."""
    glass = real.crystal("Crystal", ICE, 0.05)
    core = real.glow("Core", core_color, 7.0)
    # The tail curls off to the side, so the segments show beside the head.
    for dx, dy, dz, r in ((1.05, 0.95, 0.3, 0.3), (0.72, 0.6, 0.4, 0.38), (0.35, 0.3, 0.55, 0.45)):
        ico((x + dx, dy, z + dz), (r, r, r * 1.05), glass, 2)
        uv_sphere((x + dx, dy, z + dz), (r * 0.4, r * 0.4, r * 0.4), core, 16)
    head = ico((x, -0.1, z + 1.15), (0.62, 0.58, 0.62), glass, 2)
    head.rotation_euler = (0, 0, math.radians(15))
    uv_sphere((x, -0.1, z + 1.15), (0.25, 0.25, 0.25), core, 16)
    # Crystal spikes on the head.
    for dx, tall, lean in ((-0.25, 0.45, 20), (0.0, 0.65, 0), (0.25, 0.45, -20)):
        cone((x + dx, -0.05, z + 1.6 + tall / 2), 0.11, tall, glass, (0, math.radians(lean), 0), 5)
    # Two glowing points of eyes.
    for side in (-1, 1):
        uv_sphere((x + side * 0.22, -0.66, z + 1.22), (0.07, 0.04, 0.07), real.glow("EyeGlow", core_color, 10.0), 16)
    if extra:
        extra(x, z)


def worm_cosmic_extra(x, z):
    for dx, dz in ((-0.9, 1.7), (0.85, 1.9), (1.1, 0.9), (-1.0, 0.7)):
        uv_sphere((x + dx, -0.2, z + dz), (0.04, 0.04, 0.04), real.glow("Star", (1.0, 1.0, 1.0), 12.0), 8)


def worm_biotech_extra(x, z):
    bpy.ops.mesh.primitive_torus_add(location=(x, 0.38, z + 0.55), major_radius=0.47, minor_radius=0.05, rotation=(math.radians(90), 0, 0))
    real.assign(bpy.context.active_object, real.armor("Band", (0.5, 0.52, 0.56)))
    bpy.ops.mesh.primitive_torus_add(location=(x, 0.8, z + 0.4), major_radius=0.4, minor_radius=0.04, rotation=(math.radians(90), 0, 0))
    real.assign(bpy.context.active_object, real.armor("Band", (0.5, 0.52, 0.56)))


STYLES = [
    ("Живые инопланетяне", slime_living, crab_living, lambda x, z: crystal_worm(x, z, (0.45, 0.85, 1.0))),
    ("Космическая материя", slime_cosmic, crab_cosmic, lambda x, z: crystal_worm(x, z, (0.75, 0.55, 1.0), worm_cosmic_extra)),
    ("Био-техно", slime_biotech, crab_biotech, lambda x, z: crystal_worm(x, z, (0.3, 0.95, 1.0), worm_biotech_extra)),
]


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
    real.assign(obj, real.glow("Label", (0.75, 0.8, 0.95), 1.0))


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows = len(STYLES)
    for row, (title, *makers) in enumerate(STYLES):
        z = (rows - 1 - row) * ROW_HEIGHT
        for column, make in enumerate(makers):
            x = column * SPACING
            turn(new_objects(lambda make=make, x=x, z=z: make(x, z)), x, z, YAW)
        label(title, (-2.6, -1.0, z + 2.3), 0.3)
    for column, name in enumerate(("Слизень", "Краб", "Хрустальный червь")):
        label(name, (column * SPACING, -1.0, -0.8), 0.3)


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("use_bloom", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 2400, 1700
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    # The camera sees dark space; reflections and refractions see a soft nebula sky, so glass and
    # jelly have something to bend and mirror (a black void makes clear crystal look black).
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    dark = nodes.get("Background")
    dark.inputs["Color"].default_value = (0.004, 0.005, 0.015, 1.0)
    sky = nodes.new("ShaderNodeBackground")
    sky.inputs["Strength"].default_value = 1.4
    # A patchy nebula: dark gaps and bright clouds give the crystal facets varied glints.
    clouds = nodes.new("ShaderNodeTexNoise")
    clouds.inputs["Scale"].default_value = 3.0
    clouds.inputs["Detail"].default_value = 6
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.4
    ramp.color_ramp.elements[0].color = (0.01, 0.01, 0.04, 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (0.55, 0.8, 1.0, 1)
    middle = ramp.color_ramp.elements.new(0.55)
    middle.color = (0.35, 0.15, 0.6, 1)
    links.new(clouds.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], sky.inputs["Color"])
    sky.inputs["Strength"].default_value = 2.5
    path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(sky.outputs["Background"], mix.inputs[1])
    links.new(dark.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], nodes.get("World Output").inputs["Surface"])

    width = 2 * SPACING
    height = (len(STYLES) - 1) * ROW_HEIGHT
    target = Vector((width / 2 - 0.7, 0, height / 2 + 0.6))

    def area(name, location, energy, size, color=(1.0, 1.0, 1.0)):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    # A cool key light like a distant star, a dim warm fill, a strong blue-violet rim from behind.
    area("Key", (target.x - 6, -10, target.z + 7), 2600, 6, (0.9, 0.95, 1.0))
    area("Fill", (target.x + 8, -8, target.z), 500, 8, (1.0, 0.8, 0.7))
    area("Rim", (target.x, 9, target.z + 5), 3500, 14, (0.55, 0.6, 1.0))

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 50
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = (target.x, -26, target.z + 4.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


build()
render()
print("Wrote", OUT)
