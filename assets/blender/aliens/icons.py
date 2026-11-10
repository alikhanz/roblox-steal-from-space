# Icons of the robot pets for the game's windows (docs/design/screens/alien-icons.md): one sheet per
# guardian, a row per kind (main, second, rare, as robo_kinds.POSTS lists them) and a column per tier,
# CELL x CELL pixels each, on a transparent background with a thin dark outline. The game cuts a
# cell out of its sheet (ImageRectOffset), so 24 uploads carry all 360 icons.
#
# A pet is drawn as the game shows it without its effects: what the game hides or plays as particles
# (effect stand-ins, flame and ray cones, jetpack flames, markers, the tier ring, the rays picture) is
# left out. Meteor pets share the plain icon.
#
# Run headless from the repo root (posts are 1-24, all by default):
#   blender --background --factory-startup --python assets/blender/aliens/icons.py -- <outdir> [post ...]

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy  # noqa: E402
import robo_kinds  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = ARGS[0] if ARGS else "out/icons"
POSTS = [int(post) for post in ARGS[1:]] or list(range(1, len(robo_kinds.POSTS) + 1))

CELL = 128
# Rendered this many times bigger, then averaged down: smooth edges and a thin outline.
SUPERSAMPLE = 2
TIERS = 5
# The pet turns this far from facing the camera (degrees), and the camera looks down this much.
YAW = -28
PITCH = 14
# Room around the pet, a share of the cell.
MARGIN = 0.07
# The outline: this thick, at the cell's size (px), in the windows' glass colour.
OUTLINE = 1.5
OUTLINE_COLOR = (0.02, 0.025, 0.08)

# What the game hides (AlienDress: STAND_INS, Jet, HIDDEN_ROLES, hinges) or never gets (export: "fx").
HIDDEN_SOURCES = {"Flame", "FlameCore", "Tongue", "Ray", "RayShort", "Jet",
                  # faint auras in game (AlienDress AURAS): a grey blot on an icon
                  "Hover", "Smoke"}
# Wings and orbits may spill past the cell rather than shrink the pet: the pet's body sets the
# frame, which grows for them only up to this many times its span.
SPILL_ROLES = ("wingL", "wingR", "orbit")
SPILL_MAX = 1.45
HIDDEN_ROLES = {"fx", "ring", "rays", "flame"}
HIDDEN_PREFIXES = ("hinge", "dust")


def hidden(obj):
    role = obj.get("role", "body")
    if role in HIDDEN_ROLES or role.startswith(HIDDEN_PREFIXES):
        return True
    material = obj.data.materials[0] if getattr(obj.data, "materials", None) and obj.data.materials else None
    return material is not None and material.name.split(".")[0] in HIDDEN_SOURCES


# Wing membranes are a faint tint in game (AlienDress.colorWings: transparency 0.8; the glowing edge
# and veins carry the shape): this see-through here, so they don't hide the pet.
MEMBRANE_ALPHA = 0.3
_membranes = {}


def membrane(material):
    """A see-through copy of a wing's membrane material (one per material)."""
    copy = _membranes.get(material.name)
    if copy is None:
        copy = material.copy()
        if hasattr(copy, "surface_render_method"):
            copy.surface_render_method = "BLENDED"
        for node in copy.node_tree.nodes if copy.node_tree else ():
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Alpha"].default_value = MEMBRANE_ALPHA
        _membranes[material.name] = copy
    return copy


def thin_wings(objects):
    for obj in objects:
        if obj.type != "MESH" or not obj.get("role", "").startswith(("wingL", "wingR")):
            continue
        for index, material in enumerate(obj.data.materials):
            if material and material.name.split(".")[0].endswith("Wing"):
                obj.data.materials[index] = membrane(material)


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 48)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    size = CELL * SUPERSAMPLE
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.4
    # As the concept renders: reflections see a smooth sky with a sun, the camera sees nothing.
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

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    lights = {}
    for name, color in (("Key", (1.0, 0.97, 0.92)), ("Fill", (0.75, 0.85, 1.0)), ("Rim", (0.55, 0.65, 1.0))):
        data = bpy.data.lights.new(name, "AREA")
        data.color = color
        if name != "Key":
            data.specular_factor = 0.0
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        lights[name] = obj
    return camera, lights


# Where the concept renders put their lights against a ~26-stud scene, as (offset, energy, size):
# moved in to each pet's size with the energy kept per area (inverse square).
LIGHTS = {
    "Key": (Vector((-9, -14, 10)), 7000, 12),
    "Fill": (Vector((14, -12, 1)), 1800, 14),
    "Rim": (Vector((0, 12, 6)), 8000, 24),
}
LIGHT_REACH = 4.0


def frame(camera, lights, objects):
    """Points the camera at the pet from the front-left and above and fits it to the cell."""
    view = Matrix.Rotation(math.radians(90 - PITCH), 4, "X")
    inverse = view.inverted()

    def box(parts):
        local = [inverse @ (obj.matrix_world @ Vector(corner)) for obj in parts for corner in obj.bound_box]
        low = Vector((min(c.x for c in local), min(c.y for c in local), min(c.z for c in local)))
        high = Vector((max(c.x for c in local), max(c.y for c in local), max(c.z for c in local)))
        return low, high

    low, high = box(objects)
    body = [obj for obj in objects if not obj.get("role", "body").startswith(SPILL_ROLES)]
    body_low, body_high = box(body or objects)
    body_span = max(body_high.x - body_low.x, body_high.y - body_low.y)
    span = min(max(high.x - low.x, high.y - low.y), body_span * SPILL_MAX)
    # Centred on the whole pet, kept from sliding the body out of the cell.
    middle = (low + high) / 2
    body_middle = (body_low + body_high) / 2
    slack = (span - body_span) / 2
    middle.x = min(max(middle.x, body_middle.x - slack), body_middle.x + slack)
    middle.y = min(max(middle.y, body_middle.y - slack), body_middle.y + slack)
    camera.data.ortho_scale = span / (1 - 2 * MARGIN)
    camera.data.clip_end = 1000
    camera.matrix_world = view @ Matrix.Translation(Vector((middle.x, middle.y, high.z + 50)))
    target = view @ Vector((middle.x, middle.y, middle.z))
    reach = span * LIGHT_REACH
    for name, (offset, energy, size) in LIGHTS.items():
        scale = reach / offset.length
        light = lights[name]
        light.location = target + offset * scale
        light.data.energy = energy * scale * scale
        light.data.size = size * scale
        light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()


def render_pet(kind, tier, camera, lights, path):
    before = set(bpy.data.objects)
    robo_kinds.build(kind, tier, 0.0, 0.0)
    bpy.context.view_layer.update()
    made = [obj for obj in set(bpy.data.objects) - before]
    turn = Matrix.Rotation(math.radians(YAW), 4, "Z")
    shown = []
    for obj in made:
        if obj.parent is None:
            obj.matrix_world = turn @ obj.matrix_world
    bpy.context.view_layer.update()
    for obj in made:
        if obj.type in ("MESH", "CURVE", "META", "FONT") and not hidden(obj):
            shown.append(obj)
        else:
            obj.hide_render = True
    thin_wings(shown)
    frame(camera, lights, shown)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for obj in made:
        bpy.data.objects.remove(obj, do_unlink=True)


def load_rgba(path):
    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(height, width, 4)
    bpy.data.images.remove(image)
    return pixels


def shrink(pixels):
    """Averages SUPERSAMPLE x SUPERSAMPLE blocks, colour weighted by alpha."""
    height, width = pixels.shape[:2]
    k = SUPERSAMPLE
    alpha = pixels[..., 3:4]
    premultiplied = numpy.concatenate([pixels[..., :3] * alpha, alpha], axis=2)
    small = premultiplied.reshape(height // k, k, width // k, k, 4).mean(axis=(1, 3))
    a = small[..., 3:4]
    rgb = numpy.where(a > 1e-4, small[..., :3] / numpy.maximum(a, 1e-4), 0.0)
    return numpy.concatenate([rgb, a], axis=2)


def outlined(pixels):
    """The pet over a dark outline: its alpha grown by OUTLINE pixels (soft at the last one)."""
    alpha = pixels[..., 3]
    grown = alpha.copy()
    reach = int(math.ceil(OUTLINE))
    height, width = alpha.shape
    # Padded, not rolled: what touches one edge must not draw an outline on the opposite one.
    padded = numpy.pad(alpha, reach)
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            distance = math.hypot(dx, dy)
            if distance == 0 or distance > OUTLINE + 0.5:
                continue
            weight = min(1.0, OUTLINE + 0.5 - distance)
            shifted = padded[reach - dy:reach - dy + height, reach - dx:reach - dx + width]
            grown = numpy.maximum(grown, shifted * weight)
    back = numpy.array(OUTLINE_COLOR, dtype=numpy.float32)
    a = alpha[..., None]
    out_alpha = a + grown[..., None] * (1 - a)
    rgb = numpy.where(out_alpha > 1e-4, (pixels[..., :3] * a + back * grown[..., None] * (1 - a)) / numpy.maximum(out_alpha, 1e-4), back)
    # Empty pixels carry the outline's colour: Roblox filters images without premultiplying, so
    # black or white empty pixels would leave a halo at the edge.
    return numpy.concatenate([rgb, out_alpha], axis=2)


def write_sheet(cells, rows, path):
    sheet = numpy.zeros((rows * CELL, TIERS * CELL, 4), dtype=numpy.float32)
    sheet[..., :3] = OUTLINE_COLOR
    for (row, column), pixels in cells.items():
        # Blender's pixels run bottom-up; the sheet's rows run top-down.
        top = (rows - 1 - row) * CELL
        sheet[top:top + CELL, column * CELL:(column + 1) * CELL] = pixels
    image = bpy.data.images.new("Sheet", TIERS * CELL, rows * CELL, alpha=True)
    # The renders are already display colours (AgX applied): keep them as they are.
    image.colorspace_settings.name = "sRGB"
    image.pixels.foreach_set(sheet.ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    work = os.path.join(OUT_DIR, "cells")
    os.makedirs(work, exist_ok=True)
    camera, lights = setup_scene()
    kinds = robo_kinds.KINDS
    for post in POSTS:
        post_kinds = [kind for kind in kinds if kind[7] == post - 1]
        cells = {}
        for row, kind in enumerate(post_kinds):
            for tier in range(TIERS):
                path = os.path.abspath(os.path.join(work, f"{kind[0]}-{tier}.png"))
                render_pet(kind, tier, camera, lights, path)
                cells[(row, tier)] = outlined(shrink(load_rgba(path)))
        sheet = os.path.abspath(os.path.join(OUT_DIR, f"icons-{post_kinds[0][0]}.png"))
        write_sheet(cells, len(post_kinds), sheet)
        print("Wrote", sheet)


main()
