# The island terminals' kit of meshes (docs/design/screens/terminals.md, version 2: the holo
# projector). The rounded shapes Roblox parts can't make: the console's body, its sloped cap and the
# emitter's ring. One GLB, one node per piece, a row along X; the game gives every copy its size,
# turn, material and colour (World/TerminalKit, BayModel.buildTerminal), as with the zones' kit
# (decision 085). The rest of a terminal (its foot, stripe, lens, screen, frame and beam) is plain
# Roblox parts.
#
# Pieces are modelled at their size in game (studs), so a copy needs no rescaling; the sizes are
# BayLooks.TERMINAL_CONSOLE (keep them in step). Blender +Z is up, the front (toward the player) is
# -Y, which Roblox reads as -Z (docs/design/BLENDER_ROBLOX.md, section 1). Vertex colours are white:
# the part's colour is the whole colour.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/terminals/terminal_kit.py -- <outdir> [--sheet]
# Writes <outdir>/terminal-kit.glb; with --sheet also <outdir>/terminal-kit.png, every piece in a row.

import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SHEET = "--sheet" in ARGS
ARGS = [a for a in ARGS if a != "--sheet"]
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/terminal_kit")

# BayLooks.TERMINAL_CONSOLE, in Blender's axes (X wide, Y deep, Z high).
BODY = Vector((3.0, 2.2, 1.3))
BODY_ROUND = 0.5
CAP = Vector((2.6, 1.8, 0.3))
CAP_ROUND = 0.14
EMITTER_RADIUS = 0.7
EMITTER_THICKNESS = 0.18


def new_object(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def white(obj):
    attribute = obj.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color_srgb = (1.0, 1.0, 1.0, 1.0)
    obj.data.color_attributes.active_color = attribute


def finish(obj):
    """Applies the modifiers, smooths, centres the origin on its bounds, white vertex colours."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    obj.location = (0, 0, 0)
    white(obj)
    return obj


def rounded_box(name, size, radius, segments=4):
    """A box with every edge rounded by `radius` (a bevel), smooth shaded, sharp where flat."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = radius
    bevel.segments = segments
    bevel.limit_method = "NONE"
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.modifiers.new("Normals", "WEIGHTED_NORMAL").keep_sharp = True
    return finish(obj)


def ring(name, radius, thickness):
    """A flat ring lying in XY: `radius` to the tube's middle, `thickness` across the tube."""
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness / 2, major_segments=48, minor_segments=10)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return finish(obj)


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
    pieces = [
        rounded_box("ConsoleBody", BODY, BODY_ROUND),
        rounded_box("ConsoleCap", CAP, CAP_ROUND),
        ring("EmitterRing", EMITTER_RADIUS, EMITTER_THICKNESS),
    ]
    for piece in pieces:
        uv(piece)
        print(piece.name, "size", tuple(round(d, 3) for d in piece.dimensions))
    return pieces


def export(pieces, path):
    x = 0.0
    for piece in pieces:
        piece.location = (x, 0, 0)
        x += 5.0
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
    """Every piece in a row, lit: a check of the shapes, not the game's look."""
    mat = bpy.data.materials.new("Grey")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.45, 0.48, 0.55, 1)
    bsdf.inputs["Roughness"].default_value = 0.4
    bsdf.inputs["Metallic"].default_value = 0.4
    for piece in pieces:
        piece.data.materials.clear()
        piece.data.materials.append(mat)
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Space")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.04, 1)
    scene.world = world
    span = 5.0 * (len(pieces) - 1)
    for name, location, energy in (("Key", (span * 0.2, -20, 20), 3.5), ("Fill", (span * 0.8, -15, -5), 1.0)):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        light = new_object(name, data)
        light.rotation_euler = (Vector((span / 2, 0, 0)) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    camera_data = bpy.data.cameras.new("Cam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = span + 5.0
    camera = new_object("Cam", camera_data)
    camera.location = (span / 2, -30, 12)
    camera.rotation_euler = (Vector((span / 2, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1600, 600
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
