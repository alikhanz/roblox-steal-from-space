# Concept sheet for the aliens (docs/plans/POLISH.md, "Пришельцы"): the slime baby of the first
# guardian in its five tiers and the meteor variant, side by side, to agree on the style before
# building all 24 kinds. Decided with the user (2026-11-08): an alien is its guardian's baby; a
# higher tier wears more (spots, an antenna, crystals, a crown, sparkles); it moves by code. A
# ring in the tier's colour under it tells the tier at a glance.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/concept_slime.py -- <out.png>

import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "concept_slime.png"

# The first guardian's slime: a fresh green body; each tier's accent is its colour in the game
# (AlienLooks.TIERS).
BODY = (0.30, 0.82, 0.38)
SPOT = (0.62, 0.95, 0.62)
TIERS = [
    ("Common", (0.70, 0.72, 0.78)),
    ("Uncommon", (0.30, 0.90, 0.40)),
    ("Rare", (0.25, 0.58, 1.0)),
    ("Epic", (0.72, 0.30, 1.0)),
    ("Legendary", (1.0, 0.74, 0.18)),
]
METEOR_BODY = (0.26, 0.18, 0.17)
METEOR_GLOW = (1.0, 0.42, 0.08)
METEOR_CORE = (1.0, 0.85, 0.3)
WHITE, BLACK = (0.98, 0.98, 1.0), (0.04, 0.04, 0.07)
SPACING = 3.3
# The body: an ellipsoid with these half-axes, centred this high; its bottom sags wider.
AXES = Vector((1.0, 0.92, 0.84))
CENTER_Z = 0.86


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    return mat


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


def sphere(name, location, scale, color, segments=40):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material(name, color))
    smooth(obj)
    return obj


def cone(name, location, radius, depth, color, rotation=(0, 0, 0), vertices=6):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material(name, color))
    return obj


def surface(x, dx, z, out=0.0):
    """The point on the body's front at sideways offset `dx` and height `z`, pushed `out`."""
    u = dx / AXES.x
    w = (z - CENTER_Z) / AXES.z
    inside = max(0.0, 1 - u * u - w * w)
    return Vector((x + dx, -AXES.y * math.sqrt(inside) - out, z))


def slime_body(x, color, spot_color=None):
    body = sphere("Body", (x, 0, CENTER_Z), tuple(AXES), color, 56)
    for vertex in body.data.vertices:
        if vertex.co.z < 0:
            sag = 1 + 0.16 * (-vertex.co.z)
            vertex.co.x *= sag
            vertex.co.y *= sag
    # Big friendly eyes looking at you.
    for side in (-1, 1):
        sphere("EyeWhite", surface(x, side * 0.32, 1.02, 0.02), (0.22, 0.1, 0.26), WHITE)
        sphere("Pupil", surface(x, side * 0.32, 0.99, 0.1), (0.13, 0.05, 0.16), BLACK)
        sphere("Shine", surface(x, side * 0.27, 1.07, 0.15), (0.045, 0.02, 0.05), WHITE, 16)
        sphere("Cheek", surface(x, side * 0.58, 0.8, 0.0), (0.13, 0.05, 0.08), (1.0, 0.5, 0.55), 16)
    # A small smile: the lower half of a ring.
    bpy.ops.mesh.primitive_torus_add(
        location=surface(x, 0, 0.8, 0.0), major_radius=0.11, minor_radius=0.028, rotation=(math.radians(90), 0, 0)
    )
    smile = bpy.context.active_object
    smile.data.materials.append(material("Smile", BLACK))
    for vertex in smile.data.vertices:
        if vertex.co.y > 0.0:
            vertex.co.y = 0.0
    if spot_color:
        for dx, z, size in ((-0.7, 1.25, 0.12), (0.62, 1.32, 0.1), (0.78, 0.62, 0.11), (-0.8, 0.58, 0.09), (0.1, 1.55, 0.13)):
            sphere("Spot", surface(x, dx, z, -0.02), (size, 0.05, size * 0.9), spot_color, 16)
    return body


def ring(x, color):
    bpy.ops.mesh.primitive_torus_add(location=(x, 0, 0.03), major_radius=1.3, minor_radius=0.07)
    obj = bpy.context.active_object
    obj.data.materials.append(material("Ring", color))
    smooth(obj)


def antenna(x, color):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.5, location=(x + 0.12, 0, 1.86), rotation=(0, math.radians(14), 0))
    stalk = bpy.context.active_object
    stalk.data.materials.append(material("Stalk", (0.2, 0.55, 0.28)))
    sphere("AntennaBall", (x + 0.19, 0, 2.13), (0.14, 0.14, 0.14), color, 24)


def crystals(x, color):
    for offset, tall, lean in ((-0.32, 0.4, 20), (0.0, 0.6, 0), (0.32, 0.4, -20)):
        cone("Crystal", (x + offset, 0.0, 1.66 + tall / 2), 0.13, tall, color, (0, math.radians(lean), 0), 4)


def crown(x, color):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.42, depth=0.18, location=(x, 0.0, 1.7), vertices=24)
    band = bpy.context.active_object
    band.data.materials.append(material("Crown", color))
    for index in range(6):
        angle = math.radians(index * 60 + 90)
        cone("CrownTip", (x + 0.38 * math.cos(angle), 0.38 * math.sin(angle), 1.9), 0.09, 0.26, color)
    sphere("Gem", (x, -0.42, 1.7), (0.09, 0.05, 0.09), (0.95, 0.15, 0.4), 16)


def sparkles(x, color):
    for px, pz, size in ((-1.35, 1.6, 0.13), (1.4, 1.8, 0.16), (-1.5, 0.75, 0.1), (1.45, 0.6, 0.12), (0.0, 2.35, 0.1)):
        # A four-pointed star facing the camera: two flat diamonds crossed.
        for spin in (0, 45):
            cone("Sparkle", (x + px, -0.9, pz), size, size * 0.2, color, (math.radians(90), 0, math.radians(spin)), 4)


def meteor(x):
    slime_body(x, METEOR_BODY)
    # Glowing cracks over the dark body.
    for dx, z, tilt in ((-0.72, 0.7, 25), (0.7, 0.62, -30), (-0.45, 1.4, -35), (0.55, 1.35, 30)):
        crack = sphere("Crack", surface(x, dx, z, -0.01), (0.045, 0.03, 0.2), METEOR_GLOW, 12)
        crack.rotation_euler = (0, math.radians(tilt), 0)
    # Flames on the head: an orange drop with a yellow core.
    for offset, height in ((-0.3, 0.45), (0.0, 0.7), (0.3, 0.45)):
        cone("Flame", (x + offset, 0.0, 1.62 + height / 2), 0.16, height, METEOR_GLOW, (0, 0, 0), 12)
        cone("FlameCore", (x + offset, -0.06, 1.6 + height * 0.35), 0.08, height * 0.6, METEOR_CORE, (0, 0, 0), 12)


def label(text, x):
    bpy.ops.object.text_add(location=(x, -1.4, -0.55), rotation=(math.radians(80), 0, 0))
    obj = bpy.context.active_object
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = 0.34
    obj.data.materials.append(material("Label", (0.9, 0.92, 1.0)))


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for index, (tier, accent) in enumerate(TIERS):
        x = index * SPACING
        slime_body(x, BODY, SPOT if index >= 1 else None)
        ring(x, accent)
        if index == 2:
            antenna(x, accent)
        if index == 3:
            crystals(x, accent)
        if index == 4:
            crown(x, accent)
            sparkles(x, accent)
        label(tier, x)
    x = len(TIERS) * SPACING
    meteor(x)
    ring(x, METEOR_GLOW)
    label("Meteor", x)


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 720
    scene.view_settings.view_transform = "Standard"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_object_outline = True
    shading.object_outline_color = (0.02, 0.02, 0.05)
    shading.show_cavity = True
    shading.show_specular_highlight = True
    shading.background_type = "VIEWPORT"
    shading.background_color = (0.04, 0.05, 0.13)

    width = len(TIERS) * SPACING
    bpy.ops.object.camera_add(location=(width / 2, -14, 5.2))
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = width + 3.4
    target = Vector((width / 2, 0, 0.75))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


build()
render()
print("Wrote", OUT)
