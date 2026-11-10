# The egg's kit of meshes (docs/plans/POLISH.md, "Яйца"): the pieces a space egg is made of in
# game - a starry shell (user, 2026-11-10: "скорлупа", the dark space eggs of the Toolbox liked).
# One GLB, one node per piece, all about the egg's centre. The game gives every copy its colour, material and
# size (World/EggKit, EggLooks), so one shell serves every rarity and the meteor egg.
#
#   Shell  - the egg (a real egg profile, the top narrower), medium size 1.6 x 2.1 x 1.6 studs
#            about its centre. Nebula swirls are baked in its vertex colours (glTF COLOR_0, grey):
#            Roblox multiplies them by the part's colour, so one shell takes any rarity's colour.
#   Stars  - specks just above the shell, Neon in game.
#   Cracks - glowing cracks over the shell (epic, legendary, meteor), Neon in game.
#   Ring   - a thin flat ring, radius 1: an orbit round the egg or a halo above it.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/eggs/egg_kit.py -- <outdir> [--sheet]
# Writes <outdir>/egg-kit.glb; with --sheet also <outdir>/egg-kit.png: the rarities as the game
# dresses them (EggLooks), a check of the look before export.

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SHEET = "--sheet" in ARGS
ARGS = [a for a in ARGS if a != "--sheet"]
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/egg_kit")

# A medium egg (EggLooks.EGG_SIZE): half its width and height, studs.
HALF_WIDTH = 0.8
HALF_HEIGHT = 1.05
# How much narrower the top is than the bottom: a real egg, not a stretched ball.
TAPER = 0.11
# Shell resolution: enough for smooth swirls in vertex colours, light enough for a hundred eggs
# on screen (≈2.3k triangles).
SEGMENTS = 48
RINGS = 24


# --- Shapes --------------------------------------------------------------------------------------


def radius_at(z):
    """The shell's radius at height z from its centre."""
    w = z / HALF_HEIGHT
    if abs(w) >= 1:
        return 0.0
    return HALF_WIDTH * math.sqrt(1 - w * w) * (1 - TAPER * w)


def on_shell(angle, z, out=0.0):
    r = radius_at(z) + out
    return Vector((r * math.cos(angle), r * math.sin(angle), z))


def normal_at(angle, z):
    """The shell's outward normal at (angle, z)."""
    dz = 1e-3
    slope = (radius_at(z + dz) - radius_at(z - dz)) / (2 * dz)
    return Vector((math.cos(angle), math.sin(angle), -slope)).normalized()


def new_object(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def paint(obj, value_of):
    """Grey vertex colours: value_of(vertex position) in 0..1."""
    mesh = obj.data
    attribute = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for loop in mesh.loops:
        value = value_of(mesh.vertices[loop.vertex_index].co)
        attribute.data[loop.index].color_srgb = (value, value, value, 1.0)
    mesh.color_attributes.active_color = attribute


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


def fbm(point, octaves=4):
    total, amplitude, frequency = 0.0, 0.5, 1.0
    for _ in range(octaves):
        total += amplitude * noise.noise(point * frequency)
        amplitude *= 0.5
        frequency *= 2.0
    return total


def nebula_value(position):
    """Swirls of nebula on the shell: bright bands winding through a deep base, so the colour
    reads both dark (space) and bright (the rarity's colour). Warped noise for the swirl."""
    p = Vector(position) * 0.85
    warp = Vector((fbm(p + Vector((3.1, 0, 0))), fbm(p + Vector((0, 7.7, 0))), fbm(p + Vector((0, 0, 1.9)))))
    band = fbm(p + warp * 1.6 + Vector((11.0, 4.0, 2.0)))
    # -0.5..0.5 -> a soft band: deep 0.42, bright 1.0
    t = min(1.0, max(0.0, (band + 0.08) * 2.6))
    t = t * t * (3 - 2 * t)
    return 0.5 + 0.5 * t


def shell():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=SEGMENTS, ring_count=RINGS, radius=1)
    obj = bpy.context.active_object
    obj.name = "Shell"
    obj.data.name = "Shell"
    for vertex in obj.data.vertices:
        w = vertex.co.z
        taper = 1 - TAPER * w
        vertex.co.x *= HALF_WIDTH * taper
        vertex.co.y *= HALF_WIDTH * taper
        vertex.co.z = HALF_HEIGHT * w
    smooth(obj)
    paint(obj, nebula_value)
    return obj


def stars(seed=7, count=70):
    """Specks scattered over the shell, a few bigger ones; one mesh."""
    rng = random.Random(seed)
    mesh = bmesh.new()
    for _ in range(count):
        # Even over the surface: uniform in angle and in height (an egg is close to a cylinder
        # there), fewer near the tips.
        angle = rng.uniform(0, 2 * math.pi)
        z = rng.uniform(-0.9, 0.95) * HALF_HEIGHT
        size = 0.014 if rng.random() < 0.8 else 0.026
        centre = on_shell(angle, z, size * 0.3)
        made = bmesh.ops.create_icosphere(mesh, subdivisions=1, radius=size)
        bmesh.ops.translate(mesh, vec=centre, verts=made["verts"])
    data = bpy.data.meshes.new("Stars")
    mesh.to_mesh(data)
    mesh.free()
    obj = new_object("Stars", data)
    paint(obj, lambda _: 1.0)
    return obj


def crack_path(rng, angle, z, steps):
    """A zig-zag crack running round and down the shell from (angle, z), with a branch or two."""
    points = []
    heading = rng.choice((-1, 1))
    for _ in range(steps):
        points.append((angle, z))
        angle += heading * rng.uniform(0.05, 0.16)
        z -= rng.uniform(0.04, 0.1)
        if rng.random() < 0.35:
            heading = -heading
        if abs(z) > HALF_HEIGHT * 0.85:
            break
    return points


def tube(name, points, radius):
    """A thin tube along surface points: a curve with a bevel, made a mesh."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, (angle, z) in zip(spline.points, points):
        point.co = (*on_shell(angle, z, radius * 0.2), 1.0)
    obj = new_object(name, curve)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def cracks(seed=21):
    rng = random.Random(seed)
    parts = []
    for index in range(5):
        angle = index * 2 * math.pi / 5 + rng.uniform(-0.3, 0.3)
        main = crack_path(rng, angle, HALF_HEIGHT * rng.uniform(0.55, 0.8), 14)
        parts.append(tube(f"Crack{index}", main, 0.026))
        branch_at = main[rng.randrange(2, max(3, len(main) - 1))]
        branch = crack_path(rng, branch_at[0], branch_at[1], 4)
        if len(branch) > 1:
            parts.append(tube(f"Crack{index}b", branch, 0.018))
    obj = join("Cracks", parts)
    paint(obj, lambda _: 1.0)
    return obj


def ring():
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.03, major_segments=64, minor_segments=8)
    obj = bpy.context.active_object
    obj.name = "Ring"
    obj.data.name = "Ring"
    smooth(obj)
    paint(obj, lambda _: 1.0)
    return obj


def join(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    smooth(obj)
    return obj


# --- The kit -------------------------------------------------------------------------------------

# Piece names are the game's (World/EggKit): keep them in step.
def build():
    return [shell(), stars(), cracks(), ring()]


def export(pieces, path):
    """Every piece where the egg wears it, about the shell's centre (the origin): Studio keeps
    the nodes' places on import, so the kit in the place tells the game where each piece goes
    (World/EggKit). The ring lies flat at the centre; the game places it itself."""
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    options = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=False, export_materials="NONE")
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    triangles = sum(sum(len(p.vertices) - 2 for p in piece.data.polygons) for piece in pieces)
    print("Wrote", path, len(pieces), "pieces", triangles, "triangles", os.path.getsize(path), "bytes")


# --- The check sheet: the rarities as the game dresses them --------------------------------------

# Mirrors EggLooks (sRGB colours as in the game): shell colour, which extras, their colour.
GOLD = (1.0, 0.78, 0.35)
LADDER = [
    # name, shell, stars, orbit, cracks, halo
    ("Обычное", (0.62, 0.66, 0.78), False, False, False, False),
    ("Необычное", (0.28, 0.85, 0.42), True, False, False, False),
    ("Редкое", (0.25, 0.55, 1.0), True, True, False, False),
    ("Эпическое", (0.68, 0.3, 1.0), True, True, True, False),
    ("Легендарное", (1.0, 0.74, 0.22), True, True, True, True),
]
METEOR_SHELL = (0.42, 0.28, 0.24)
METEOR_GLOW = (1.0, 0.45, 0.1)


def srgb_to_linear(color):
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color)


def shell_material(name, color):
    """Vertex colour x part colour, glossy: as Roblox draws a SmoothPlastic MeshPart under
    Realistic lighting (with a touch more coat, for the look the user asked for, decision 072)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.22
    bsdf.inputs["Coat Weight"].default_value = 0.6
    bsdf.inputs["Coat Roughness"].default_value = 0.08
    vertex = nodes.new("ShaderNodeVertexColor")
    vertex.layer_name = "Col"
    tint = nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    tint.inputs[7].default_value = (*srgb_to_linear(color), 1)
    links.new(vertex.outputs["Color"], tint.inputs[6])
    links.new(tint.outputs[2], bsdf.inputs["Base Color"])
    return mat


def neon_material(name, color, strength=3.0, alpha=1.0):
    """Roblox Neon: flat, glowing in its colour."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    linear = srgb_to_linear(color)
    bsdf.inputs["Base Color"].default_value = (*linear, 1)
    bsdf.inputs["Emission Color"].default_value = (*linear, 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 1 and hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    return mat


def place(piece, name, location, mat, scale=1.0, rotation=(0, 0, 0)):
    copy = piece.copy()
    copy.data = piece.data.copy()
    copy.name = name
    copy.hide_render = False
    bpy.context.scene.collection.objects.link(copy)
    copy.location = location
    copy.scale = (scale, scale, scale)
    copy.rotation_euler = rotation
    copy.data.materials.clear()
    copy.data.materials.append(mat)
    return copy


def dress(kit, base, shell_color, stars_on, orbit, cracks_on, halo, glow_color, scale=1.0):
    """One egg at `base` (its bottom) as the game builds it."""
    shell_piece, stars_piece, cracks_piece, ring_piece = kit
    centre = base + Vector((0, 0, HALF_HEIGHT * scale))
    place(shell_piece, "Egg", centre, shell_material("Shell", shell_color), scale)
    light = tuple(c + (1 - c) * 0.35 for c in glow_color)
    if stars_on:
        place(stars_piece, "Stars", centre, neon_material("Stars", (1.0, 0.98, 0.92), 2.5), scale)
    if cracks_on:
        place(cracks_piece, "Cracks", centre, neon_material("Cracks", light, 3.0), scale)
    if orbit:
        place(ring_piece, "Orbit", centre, neon_material("Orbit", light, 2.5, 0.85), scale * 1.35, (math.radians(16), math.radians(-22), 0))
    if halo:
        place(ring_piece, "Halo", centre + Vector((0, 0, (HALF_HEIGHT + 0.35) * scale)), neon_material("Halo", GOLD, 3.0), scale * 0.38)


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
    obj.data.materials.append(neon_material("Label", (0.75, 0.8, 0.95), 1.2))


def sheet(kit, path):
    for piece in kit:
        piece.hide_render = True
    spacing = 2.9
    row = 5.2
    # Top row: the rarities and the meteor egg, medium; bottom row: the Rare egg's three sizes,
    # then a large epic and legendary.
    for index, (name, color, stars_on, orbit, cracks_on, halo) in enumerate(LADDER):
        dress(kit, Vector((index * spacing, 0, row)), color, stars_on, orbit, cracks_on, halo, color)
        label(name, (index * spacing, -1.2, row - 0.75), 0.28)
    dress(kit, Vector((5 * spacing, 0, row)), METEOR_SHELL, False, False, True, False, METEOR_GLOW)
    label("Метеоритное", (5 * spacing, -1.2, row - 0.75), 0.28)
    for name, scale, x in (("Маленькое", 0.65, 0.0), ("Среднее", 1.0, 2.5), ("Большое", 1.5, 6.3)):
        dress(kit, Vector((x, 0, 0)), LADDER[2][1], True, True, False, False, LADDER[2][1], scale)
        label(name, (x, -1.2, -0.75), 0.28)
    for (name, color, stars_on, orbit, cracks_on, halo), x in zip(LADDER[3:], (10.6, 14.6)):
        dress(kit, Vector((x, 0, 0)), color, stars_on, orbit, cracks_on, halo, color, 1.5)
        label(f"{name}, большое", (x, -1.2, -0.75), 0.28)
    render(Vector((7.3, 0, row / 2 + 1.0)), path)


def render(target, path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(scene.eevee, attribute):
            setattr(scene.eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 2700, 1500
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.25
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    dark = nodes.get("Background")
    dark.inputs["Color"].default_value = (0.006, 0.008, 0.025, 1.0)
    sky = nodes.new("ShaderNodeBackground")
    sky.inputs["Strength"].default_value = 0.0
    texture = nodes.new("ShaderNodeTexSky")
    links.new(texture.outputs["Color"], sky.inputs["Color"])
    light_path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(light_path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(sky.outputs["Background"], mix.inputs[1])
    links.new(dark.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], nodes.get("World Output").inputs["Surface"])

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        if name != "Key":
            data.specular_factor = 0.0
        obj = new_object(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()

    area("Key", (target.x - 9, -14, target.z + 10), 6000, 12, (1.0, 0.97, 0.92))
    area("Fill", (target.x + 14, -12, target.z + 1), 1600, 14, (0.75, 0.85, 1.0))
    area("Rim", (target.x, 12, target.z + 6), 7000, 24, (0.55, 0.65, 1.0))
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 50
    camera = new_object("Camera", camera_data)
    camera.location = (target.x, -28, target.z + 2.5)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Wrote", path)


bpy.ops.wm.read_factory_settings(use_empty=True)
os.makedirs(OUT_DIR, exist_ok=True)
kit = build()
export(kit, os.path.join(OUT_DIR, "egg-kit.glb"))
if SHEET:
    sheet(kit, os.path.join(OUT_DIR, "egg-kit.png"))
