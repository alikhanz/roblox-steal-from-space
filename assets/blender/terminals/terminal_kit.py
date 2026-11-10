# The island terminals' kit of meshes (docs/design/screens/terminals.md, version 2: the holo
# projector; decision 086). A terminal is two meshes, one per material, and its screen (a plain
# Roblox part the screen is drawn on):
#
#   Console - the foot, the rounded body and the sloped cap, Metal; their shades (dark foot, mid
#             body, light cap) are baked in the vertex colours, the game gives the cap's colour;
#   Glow    - everything glowing in the zone's colour, Neon: the stripe on the front, the emitter's
#             ring and lens on the cap, the screen's frame and its corner lights.
#
# Both are modelled where they stand on a terminal: origin on the floor under its middle, front
# (toward the player) -Y, which Roblox reads as -Z (docs/design/BLENDER_ROBLOX.md, section 1). They
# are exported on top of each other at the origin, so in the place the Console's bottom middle
# gives every piece its pivot (World/TerminalKit): the game puts a copy on a terminal with one
# PivotTo. The numbers are BayLooks.TERMINAL_* (keep them in step).
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/terminals/terminal_kit.py -- <outdir> [--sheet]
# Writes <outdir>/terminal-kit.glb; with --sheet also <outdir>/terminal-kit.png, a look at the kit.

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SHEET = "--sheet" in ARGS
ARGS = [a for a in ARGS if a != "--sheet"]
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/terminal_kit")

# BayLooks.TERMINAL_*, in Blender's axes (X wide, Y deep, Z high).
FOOT_RADIUS, FOOT_HEIGHT = 1.9, 0.3
BODY = Vector((3.0, 2.2, 1.3))
BODY_ROUND = 0.5
CAP = Vector((2.6, 1.8, 0.3))
CAP_ROUND = 0.14
CAP_SINK, CAP_TILT = 0.1, math.radians(12)
EMITTER_RADIUS, EMITTER_THICKNESS = 0.7, 0.17
LENS_RADIUS, LENS_THICKNESS = 0.55, 0.08
STRIPE = Vector((1.8, 0.08, 0.14))
STRIPE_HEIGHT = 0.65
SCREEN_W, SCREEN_H = 6.0, 4.0
SCREEN_HEIGHT, SCREEN_TILT = 5.0, math.radians(15)
FRAME_WIDTH, CORNER_SIZE = 0.08, 0.24
# BayLooks.TERMINAL_SHADES: the console's parts against its cap.
SHADES = {"foot": 0.44, "body": 0.67, "cap": 1.0}


def new_object(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def shade(obj, value):
    attribute = obj.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color_srgb = (value, value, value, 1.0)
    obj.data.color_attributes.active_color = attribute


def place(obj, matrix):
    """Applies the modifiers, then puts the object where `matrix` says (in the terminal's frame)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.matrix_world = matrix
    return obj


def rounded_box(name, size, radius, matrix, segments=4):
    """A box with every edge rounded by `radius`, smooth shaded, sharp where flat."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if radius > 0:
        bevel = obj.modifiers.new("Bevel", "BEVEL")
        bevel.width = radius
        bevel.segments = segments
        bevel.limit_method = "NONE"
        for poly in obj.data.polygons:
            poly.use_smooth = True
        obj.modifiers.new("Normals", "WEIGHTED_NORMAL").keep_sharp = True
    return place(obj, matrix)


def disc(name, radius, depth, matrix, vertices=40):
    """A flat cylinder, its axis along the matrix's Z."""
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=vertices)
    obj = bpy.context.active_object
    obj.name = name
    return place(obj, matrix)


def ring(name, radius, thickness, matrix):
    """A ring lying in the matrix's XY: `radius` to the tube's middle, `thickness` across the tube."""
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness / 2, major_segments=40, minor_segments=8)
    obj = bpy.context.active_object
    obj.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return place(obj, matrix)


def ball(name, size, matrix):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=size / 2, segments=12, ring_count=6)
    obj = bpy.context.active_object
    obj.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return place(obj, matrix)


def join(name, parts):
    """Joins the parts into one mesh named `name`, its origin left at the terminal's (the world's)."""
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    return obj


def at(x, y, z):
    return Matrix.Translation((x, y, z))


def tilt(angle):
    """Turned about X: a positive angle leans the top toward the front (-Y)."""
    return Matrix.Rotation(angle, 4, "X")


def console():
    foot = disc("Foot", FOOT_RADIUS, FOOT_HEIGHT, at(0, 0, FOOT_HEIGHT / 2), 48)
    shade(foot, SHADES["foot"])
    body = rounded_box("Body", BODY, BODY_ROUND, at(0, 0, FOOT_HEIGHT + BODY.z / 2))
    shade(body, SHADES["body"])
    cap = rounded_box("Cap", CAP, CAP_ROUND, cap_frame())
    shade(cap, SHADES["cap"])
    return join("Console", [foot, body, cap])


def cap_frame():
    return at(0, 0, FOOT_HEIGHT + BODY.z + CAP.z / 2 - CAP_SINK) @ tilt(CAP_TILT)


def glow():
    cap_top = cap_frame() @ at(0, 0, CAP.z / 2)
    parts = [
        # The stripe on the body's flat front, half sunk into it.
        rounded_box("Stripe", STRIPE, 0, at(0, -(BODY.y + STRIPE.y / 2) / 2, FOOT_HEIGHT + STRIPE_HEIGHT)),
        ring("Emitter", EMITTER_RADIUS, EMITTER_THICKNESS, cap_top),
        disc("Lens", LENS_RADIUS, LENS_THICKNESS, cap_top @ at(0, 0, LENS_THICKNESS / 2)),
    ]
    # The screen's frame: its top leans back (+Y), away from the player.
    screen = at(0, 0, SCREEN_HEIGHT) @ tilt(-SCREEN_TILT)
    half_w, half_h = (SCREEN_W + FRAME_WIDTH) / 2, (SCREEN_H + FRAME_WIDTH) / 2
    for side in (-1, 1):
        parts.append(rounded_box("Bar", Vector((SCREEN_W + FRAME_WIDTH * 2, FRAME_WIDTH, FRAME_WIDTH)), 0, screen @ at(0, 0, side * half_h)))
        parts.append(rounded_box("Bar", Vector((FRAME_WIDTH, FRAME_WIDTH, SCREEN_H)), 0, screen @ at(side * half_w, 0, 0)))
        for level in (-1, 1):
            parts.append(ball("Corner", CORNER_SIZE, screen @ at(side * half_w, 0, level * half_h)))
    for part in parts:
        shade(part, 1.0)
    return join("Glow", parts)


def uv(obj):
    """UVs for the Roblox material's texture: a smart projection, islands at the mesh's own scale."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


# Piece names are the game's (World/TerminalKit): keep them in step.
def build():
    pieces = [console(), glow()]
    for piece in pieces:
        uv(piece)
        corners = [piece.matrix_world @ Vector(c) for c in piece.bound_box]
        low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
        high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
        print(piece.name, "bounds", tuple(round(v, 3) for v in low), tuple(round(v, 3) for v in high))
    return pieces


def export(pieces, path):
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    options = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=True, export_materials="NONE")
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    triangles = sum(sum(len(p.vertices) - 2 for p in piece.data.polygons) for piece in pieces)
    print("Wrote", path, len(pieces), "pieces", triangles, "triangles", os.path.getsize(path), "bytes")


def sheet(pieces, path):
    """The kit as a terminal, from the front and a little to the side: a check of the shapes."""
    metal = bpy.data.materials.new("Metal")
    metal.use_nodes = True
    nodes, links = metal.node_tree.nodes, metal.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    colour = nodes.new("ShaderNodeVertexColor")
    colour.layer_name = "Col"
    tint = nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    tint.inputs[7].default_value = (0.72, 0.75, 0.82, 1)
    links.new(colour.outputs["Color"], tint.inputs[6])
    links.new(tint.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.4
    bsdf.inputs["Roughness"].default_value = 0.35
    neon = bpy.data.materials.new("Neon")
    neon.use_nodes = True
    neon_bsdf = neon.node_tree.nodes.get("Principled BSDF")
    neon_bsdf.inputs["Emission Color"].default_value = (1.0, 0.55, 0.1, 1)
    neon_bsdf.inputs["Emission Strength"].default_value = 3.0
    for piece, material in zip(pieces, (metal, neon)):
        piece.data.materials.clear()
        piece.data.materials.append(material)
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Space")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.04, 1)
    scene.world = world
    sun = bpy.data.lights.new("Key", "SUN")
    sun.energy = 3.5
    light = new_object("Key", sun)
    light.rotation_euler = (math.radians(50), math.radians(-20), math.radians(-30))
    camera_data = bpy.data.cameras.new("Cam")
    camera_data.lens = 35
    camera = new_object("Cam", camera_data)
    camera.location = (8, -14, 6)
    camera.rotation_euler = (Vector((0, 0, 3.2)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Wrote", path)


bpy.ops.wm.read_factory_settings(use_empty=True)
os.makedirs(OUT_DIR, exist_ok=True)
kit = build()
export(kit, os.path.join(OUT_DIR, "terminal-kit.glb"))
if SHEET:
    sheet(kit, os.path.join(OUT_DIR, "terminal-kit.png"))
