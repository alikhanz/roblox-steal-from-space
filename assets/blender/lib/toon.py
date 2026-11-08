# The shared look of the game's 3D (decision 072): glossy cartoon surfaces under a clear coat,
# soft studio light, a dark outline round the silhouette only. Every concept and model script
# builds with these helpers, so all aliens, eggs and props share one style.

import math

import bpy
from mathutils import Vector

OUTLINE = (0.02, 0.02, 0.05)
BACKGROUND = (0.04, 0.05, 0.13)
WHITE = (0.98, 0.98, 1.0)
BLACK = (0.04, 0.04, 0.07)
CHEEK = (1.0, 0.5, 0.55)
# A font with Cyrillic for labels (Blender's own has none).
LABEL_FONT = "C:/Windows/Fonts/segoeuib.ttf"


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness=0.22, coat=0.7, emission=0.0):
    """A glossy candy-like surface; `emission` > 0 makes it glow in its own colour."""
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = 0.08
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def no_outline(obj):
    """Details painted on a body (spots, cheeks, cracks) and labels get no outline: the cartoon
    line goes round the figure, not round every spot."""
    plain = bpy.data.collections.get("NoOutline") or bpy.data.collections.new("NoOutline")
    if plain.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(plain)
    for collection in obj.users_collection:
        collection.objects.unlink(obj)
    plain.objects.link(obj)
    return obj


def sphere(name, location, scale, color, segments=40, **look):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material(name, color, **look))
    return smooth(obj)


def cone(name, location, radius, depth, color, rotation=(0, 0, 0), vertices=6, radius2=0.0, **look):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius, radius2=radius2, depth=depth, location=location, rotation=rotation
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material(name, color, **look))
    return obj


def cylinder(name, location, radius, depth, color, rotation=(0, 0, 0), vertices=24, **look):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material(name, color, **look))
    return smooth(obj)


def torus(name, location, major, minor, color, rotation=(0, 0, 0), **look):
    bpy.ops.mesh.primitive_torus_add(location=location, major_radius=major, minor_radius=minor, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material(name, color, **look))
    return smooth(obj)


def face(at, spacing, size, look_down=0.0, smile=True, cheeks=True):
    """Big friendly eyes looking at the viewer (-Y), a small smile and blush, around `at` (the
    point between the eyes on the surface). `size` scales the whole face."""
    x, y, z = at
    for side in (-1, 1):
        sphere("EyeWhite", (x + side * spacing, y, z), (0.22 * size, 0.1 * size, 0.26 * size), WHITE)
        sphere("Pupil", (x + side * spacing, y - 0.08 * size, z - 0.03 * size - look_down), (0.13 * size, 0.05 * size, 0.16 * size), BLACK)
        sphere("Shine", (x + side * spacing - 0.05 * size, y - 0.13 * size, z + 0.05 * size), (0.045 * size, 0.02 * size, 0.05 * size), WHITE, 16)
        if cheeks:
            no_outline(sphere("Cheek", (x + side * spacing * 1.75, y + 0.06 * size, z - 0.22 * size), (0.13 * size, 0.04 * size, 0.08 * size), CHEEK, 16, roughness=0.6, coat=0.0))
    if smile:
        mouth = torus("Smile", (x, y - 0.01, z - 0.22 * size), 0.11 * size, 0.028 * size, BLACK, (math.radians(90), 0, 0))
        for vertex in mouth.data.vertices:
            if vertex.co.y > 0.0:
                vertex.co.y = 0.0
        no_outline(mouth)


def label(text, location, size=0.34):
    bpy.ops.object.text_add(location=location, rotation=(math.radians(80), 0, 0))
    obj = bpy.context.active_object
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = size
    try:
        obj.data.font = bpy.data.fonts.load(LABEL_FONT, check_existing=True)
    except RuntimeError:
        pass
    obj.data.materials.append(material("Label", (0.9, 0.92, 1.0), roughness=0.8, coat=0.0))
    return no_outline(obj)


def _light(name, location, energy, size, target, color=(1.0, 1.0, 1.0)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(obj)


def render(
    out, width, height, center, ortho_scale, resolution=(2400, 1100), camera_height=5.0, camera_side=0.0, light_scale=1.0
):
    """Renders the scene: EEVEE for the glossy coat, Freestyle for the outline. `center` is what
    the camera looks at; `width`/`height` of the sheet set where the lights stand; `camera_side`
    swings the camera sideways for a three-quarter view."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 2.2
    settings = scene.view_layers[0].freestyle_settings
    lineset = settings.linesets[0] if len(settings.linesets) > 0 else settings.linesets.new("Outline")
    lineset.linestyle = lineset.linestyle or bpy.data.linestyles.new("Outline")
    lineset.linestyle.color = OUTLINE
    lineset.select_by_edge_types = True
    lineset.select_silhouette = True
    lineset.select_border = True
    lineset.select_crease = False
    plain = bpy.data.collections.get("NoOutline")
    if plain:
        lineset.select_by_collection = True
        lineset.collection = plain
        lineset.collection_negation = "EXCLUSIVE"

    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (*BACKGROUND, 1.0)
    background.inputs["Strength"].default_value = 0.8

    cx, cy, cz = center
    target = (cx, cy, cz)
    _light("Key", (cx - width * 0.3, -9, cz + 6 + height * 0.3), 750 * light_scale, 10 + width * 0.3, target)
    _light("Fill", (cx + width * 0.4, -8, cz + 2), 220 * light_scale, 8 + width * 0.2, target)
    _light("Rim", (cx, 6, cz + 6), 450 * light_scale, 12 + width * 0.3, target, (0.7, 0.8, 1.0))

    bpy.ops.object.camera_add(location=(cx + camera_side, -14, cz + camera_height))
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho_scale
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
