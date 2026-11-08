# Concept sheet for the space eggs (docs/plans/POLISH.md, "Яйца"), in the style of the alien
# concept (assets/blender/aliens/concept_slime.py): one egg per rarity and the meteor egg, to
# compare with free eggs from the Roblox Toolbox before choosing (user, 2026-11-08). A rarer egg
# wears more: spots, a band of stars, crystals, a crown; its colour is the rarity's
# (EggLooks.RARITIES).
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/eggs/concept_eggs.py -- <out.png>

import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "concept_eggs.png"

RARITIES = [
    ("Common", (0.88, 0.90, 0.94), None),
    ("Uncommon", (0.47, 0.92, 0.51), (0.85, 1.0, 0.85)),
    ("Rare", (0.35, 0.67, 1.0), (0.85, 0.93, 1.0)),
    ("Epic", (0.78, 0.35, 1.0), (0.95, 0.85, 1.0)),
    ("Legendary", (1.0, 0.78, 0.24), (1.0, 0.97, 0.8)),
]
METEOR = (0.27, 0.19, 0.17)
METEOR_GLOW = (1.0, 0.42, 0.08)
SPACING = 2.6
# The egg: an ellipsoid stretched up, narrower at the top.
HALF = Vector((0.8, 0.8, 1.05))
CENTER_Z = 1.15


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


def cone(name, location, radius, depth, color, rotation=(0, 0, 0), vertices=4):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.data.materials.append(material(name, color))
    return obj


def radius_at(z):
    """The egg's radius at height z (an egg: the top half narrower)."""
    w = (z - CENTER_Z) / HALF.z
    base = HALF.x * math.sqrt(max(0.0, 1 - w * w))
    return base * (1 - 0.18 * max(0.0, w))


def on_egg(x, angle, z, out=0.0):
    r = radius_at(z) + out
    return Vector((x + r * math.sin(angle), -r * math.cos(angle), z))


def egg(x, color):
    body = sphere("Egg", (x, 0, CENTER_Z), tuple(HALF), color, 56)
    for vertex in body.data.vertices:
        if vertex.co.z > 0:
            taper = 1 - 0.18 * vertex.co.z
            vertex.co.x *= taper
            vertex.co.y *= taper
    # A soft shine on the upper left.
    sphere("Shine", on_egg(x, -0.5, 1.75, 0.0), (0.12, 0.05, 0.2), (1.0, 1.0, 1.0), 16)
    return body


def spots(x, color):
    for angle, z, size in ((0.5, 1.45, 0.14), (-0.3, 0.9, 0.17), (0.25, 0.55, 0.11), (-0.65, 1.35, 0.1)):
        sphere("Spot", on_egg(x, angle, z, -0.03), (size, 0.06, size * 1.1), color, 16)


def star_band(x, color):
    bpy.ops.mesh.primitive_torus_add(location=(x, 0, 1.0), major_radius=radius_at(1.0) + 0.01, minor_radius=0.07)
    band = bpy.context.active_object
    band.data.materials.append(material("Band", color))
    smooth(band)
    for angle in (-0.7, 0.0, 0.7):
        for spin in (0, 45):
            point = on_egg(x, angle, 1.0, 0.08)
            cone("Star", point, 0.11, 0.03, (1.0, 1.0, 1.0), (math.radians(90), 0, math.radians(spin)))


def crystals(x, color):
    for offset, tall, lean in ((-0.18, 0.32, 25), (0.0, 0.45, 0), (0.18, 0.32, -25)):
        cone("Crystal", (x + offset, 0, 2.1 + tall / 2), 0.09, tall, color, (0, math.radians(lean), 0))


def crown(x, color):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.14, location=(x, 0, 2.12), vertices=24)
    band = bpy.context.active_object
    band.data.materials.append(material("Crown", color))
    for index in range(6):
        angle = math.radians(index * 60 + 90)
        cone("CrownTip", (x + 0.27 * math.cos(angle), 0.27 * math.sin(angle), 2.3), 0.07, 0.2, color, vertices=6)


def meteor_egg(x):
    egg(x, METEOR)
    for angle, z, tilt in ((-0.5, 0.8, 25), (0.45, 0.7, -30), (-0.2, 1.5, -35), (0.5, 1.45, 30), (0.0, 1.1, 0)):
        crack = sphere("Crack", on_egg(x, angle, z, -0.01), (0.04, 0.03, 0.2), METEOR_GLOW, 12)
        crack.rotation_euler = (0, math.radians(tilt), 0)
    for offset, height in ((-0.2, 0.35), (0.0, 0.55), (0.2, 0.35)):
        cone("Flame", (x + offset, 0, 2.08 + height / 2), 0.12, height, METEOR_GLOW, vertices=12)


def stand(x):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.75, depth=0.18, location=(x, 0, 0.09), vertices=32)
    base = bpy.context.active_object
    base.data.materials.append(material("Stand", (0.32, 0.35, 0.48)))


def label(text, x):
    bpy.ops.object.text_add(location=(x, -1.2, -0.45), rotation=(math.radians(80), 0, 0))
    obj = bpy.context.active_object
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = 0.28
    obj.data.materials.append(material("Label", (0.9, 0.92, 1.0)))


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for index, (rarity, color, accent) in enumerate(RARITIES):
        x = index * SPACING
        stand(x)
        egg(x, color)
        if index >= 1:
            spots(x, accent)
        if index >= 2:
            star_band(x, accent)
        if index == 3:
            crystals(x, color)
        if index == 4:
            crown(x, color)
        label(rarity, x)
    x = len(RARITIES) * SPACING
    stand(x)
    meteor_egg(x)
    label("Meteor", x)


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 760
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

    width = len(RARITIES) * SPACING
    bpy.ops.object.camera_add(location=(width / 2, -14, 4.6))
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = width + 2.8
    target = Vector((width / 2, 0, 0.95))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


build()
render()
print("Wrote", OUT)
