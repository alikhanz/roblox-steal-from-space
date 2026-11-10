# The egg's kit of meshes (docs/plans/POLISH.md, "Яйца"; decision 087): the pieces a space egg is
# made of in game - a ceramic capsule like the pets' hulls and the station's kiosks (user,
# 2026-11-10, after the starry shell and the kiosk capsules: "мне нравятся больше капсулы, которые
# ты ранее показывал"). One GLB, one node per piece, all about the egg's centre (the origin). The
# game gives every copy its colour, material and size (World/EggKit, EggLooks), so one set of
# shapes serves every rarity and the meteor egg.
#
#   Base    - the lower shell, up to the seam, with a foot ring and the porthole's rim (both
#             darker in the vertex colours: Roblox multiplies them by the part's colour).
#   Cap     - the upper shell above the seam: the rarity's colour.
#   Seam    - the band in the gap between them: glows from uncommon up.
#   Window  - the porthole's glass: glows from rare up.
#   Antenna - a short rod on top (epic and up); Tip - its light.
#   Cracks  - lava cracks over the shell (the meteor egg).
#   Ring    - a thin flat ring, radius 1: an orbit round the egg or a halo above it.
#   Centre  - a speck at the egg's centre: only a reference for where the others sit
#             (World/EggKit); never worn.
#
# A medium egg is 1.6 x 2.1 x 1.6 studs (EggLooks.EGG_SIZE), its porthole facing -Y here.
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
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SHEET = "--sheet" in ARGS
ARGS = [a for a in ARGS if a != "--sheet"]
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/egg_kit")

# A medium egg (EggLooks.EGG_SIZE): half its width and height, studs.
HALF_WIDTH = 0.8
HALF_HEIGHT = 1.05
# How much narrower the top is than the bottom: a real egg, not a stretched ball.
TAPER = 0.11
SEGMENTS = 32
RINGS = 16
# The seam between base and cap: its middle (height from the centre) and half the gap.
SEAM_Z = 0.13
GAP = 0.05
# The porthole: height of its middle, and its rim's and glass's half sizes (across, up, depth).
PORTHOLE_Z = -0.35
RIM = (0.25, 0.33, 0.08)
GLASS = (0.19, 0.27, 0.07)
# Vertex shades of the darker parts of the base.
FOOT_SHADE = 0.4
RIM_SHADE = 0.3


# --- Shapes --------------------------------------------------------------------------------------


def radius_at(z):
    """The shell's radius at height z from its centre."""
    w = z / HALF_HEIGHT
    if abs(w) >= 1:
        return 0.0
    return HALF_WIDTH * math.sqrt(1 - w * w) * (1 - TAPER * w)


def front(z, out=0.0):
    """The point on the shell's front (-Y) at height z, `out` above the surface."""
    return Vector((0.0, -(radius_at(z) + out), z))


def on_shell(angle, z, out=0.0):
    r = radius_at(z) + out
    return Vector((r * math.cos(angle), r * math.sin(angle), z))


def facing_front(z):
    """Euler turn laying a flat thing on the front of the shell at height z: Rx(90) points its
    local Z at the front; below the widest point the surface faces a little down, so add the
    slope's tilt."""
    dz = 1e-3
    slope = (radius_at(z + dz) - radius_at(z - dz)) / (2 * dz)
    return (math.radians(90) + math.atan(slope), 0, 0)


def new_object(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def paint(obj, value):
    """Grey vertex colours, one shade for the whole object."""
    mesh = obj.data
    attribute = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color_srgb = (value, value, value, 1.0)
    mesh.color_attributes.active_color = attribute
    return obj


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def apply(obj):
    """Bakes the object's place, turn and scale into its mesh: every piece's origin is the egg's
    centre, so a copy put at an egg's centre wears the piece where it belongs."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
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
    return obj


def shell_band(name, zmin=None, zmax=None, inset=0.0):
    """The egg's shell between heights zmin and zmax (from the centre); `inset` shrinks it."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=SEGMENTS, ring_count=RINGS, radius=1)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    for vertex in obj.data.vertices:
        w = vertex.co.z
        taper = 1 - TAPER * w
        vertex.co.x *= (HALF_WIDTH - inset) * taper
        vertex.co.y *= (HALF_WIDTH - inset) * taper
        vertex.co.z = (HALF_HEIGHT - inset) * w
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    if zmin is not None:
        geom = mesh.verts[:] + mesh.edges[:] + mesh.faces[:]
        bmesh.ops.bisect_plane(mesh, geom=geom, plane_co=(0, 0, zmin), plane_no=(0, 0, 1), clear_inner=True)
    if zmax is not None:
        geom = mesh.verts[:] + mesh.edges[:] + mesh.faces[:]
        bmesh.ops.bisect_plane(mesh, geom=geom, plane_co=(0, 0, zmax), plane_no=(0, 0, 1), clear_outer=True)
    mesh.to_mesh(obj.data)
    mesh.free()
    return smooth(obj)


def blob(name, centre, half, rotation):
    """A flattened ball (rim, glass) laid on the shell."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=6, radius=1, location=centre)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = half
    obj.rotation_euler = rotation
    return apply(smooth(obj))


def base():
    shell = paint(shell_band("BaseShell", zmax=SEAM_Z - GAP), 1.0)
    foot_z = -HALF_HEIGHT + 0.16
    bpy.ops.mesh.primitive_torus_add(location=(0, 0, foot_z), major_radius=radius_at(foot_z) - 0.02, minor_radius=0.06, major_segments=20, minor_segments=4)
    foot = paint(smooth(bpy.context.active_object), FOOT_SHADE)
    rim = paint(blob("Rim", front(PORTHOLE_Z, -0.06), RIM, facing_front(PORTHOLE_Z)), RIM_SHADE)
    return join("Base", [shell, foot, rim])


def cap():
    return paint(shell_band("Cap", zmin=SEAM_Z + GAP), 1.0)


def seam():
    return paint(shell_band("Seam", zmin=SEAM_Z - GAP - 0.01, zmax=SEAM_Z + GAP + 0.01, inset=0.012), 1.0)


def window():
    obj = blob("Window", front(PORTHOLE_Z, -0.015), GLASS, facing_front(PORTHOLE_Z))
    obj.name = obj.data.name = "Window"
    return paint(obj, 1.0)


def antenna():
    top = HALF_HEIGHT - 0.02
    bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=0.28, location=(0, 0, top + 0.1), vertices=8)
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Antenna"
    return paint(apply(obj), 1.0)


def tip():
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(0, 0, HALF_HEIGHT - 0.02 + 0.27), segments=10, ring_count=5)
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Tip"
    return paint(apply(smooth(obj)), 1.0)


def crack_path(rng, angle, z, steps):
    """A zig-zag crack running round and down the shell from (angle, z)."""
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
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 0
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
    return paint(smooth(join("Cracks", parts)), 1.0)


def ring():
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.03, major_segments=32, minor_segments=4)
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Ring"
    return paint(smooth(obj), 1.0)


def centre():
    bpy.ops.mesh.primitive_cube_add(size=0.02, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Centre"
    return paint(obj, 1.0)


# --- The kit -------------------------------------------------------------------------------------

# Piece names are the game's (World/EggKit): keep them in step.
def build():
    pieces = [base(), cap(), seam(), window(), antenna(), tip(), cracks(), ring(), centre()]
    for piece in pieces:
        # Each piece's origin is the egg's centre (see apply): the sheet wears copies there.
        assert piece.location.length < 1e-6, f"{piece.name} is not about the egg's centre"
    return pieces


def export(pieces, path):
    """Every piece where the egg wears it, about the egg's centre (the origin): Studio keeps the
    nodes' places on import, so the kit in the place tells the game where each piece goes
    (World/EggKit, measured from `Centre`). The ring lies flat at the centre; the game places it."""
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    options = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=False, export_materials="NONE")
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    counts = {piece.name: sum(len(p.vertices) - 2 for p in piece.data.polygons) for piece in pieces}
    print("Wrote", path, len(pieces), "pieces", sum(counts.values()), "triangles", os.path.getsize(path), "bytes")
    print("Triangles:", ", ".join(f"{name} {count}" for name, count in counts.items()))


# --- The check sheet: the rarities as the game dresses them --------------------------------------

# Mirrors EggLooks (sRGB as in the game).
PEARL = (0.925, 0.937, 0.961)
UNLIT = (0.25, 0.26, 0.3)
ROD = (0.3, 0.32, 0.38)
GOLD = (1.0, 0.78, 0.35)
LADDER = [
    # name, colour, cap (None: pearl), seam lit, window lit, antenna, orbit, halo
    ("Обычное", (0.886, 0.902, 0.941), None, False, False, False, False, False),
    ("Необычное", (0.28, 0.85, 0.42), (0.28, 0.85, 0.42), True, False, False, False, False),
    ("Редкое", (0.25, 0.55, 1.0), (0.25, 0.55, 1.0), True, True, False, False, False),
    ("Эпическое", (0.68, 0.3, 1.0), (0.68, 0.3, 1.0), True, True, True, True, False),
    ("Легендарное", (1.0, 0.78, 0.24), GOLD, True, True, True, True, True),
]
METEOR_SHELL = (0.35, 0.23, 0.19)
METEOR_GLOW = (1.0, 0.47, 0.12)
ORBIT = (1.1, (math.radians(72), math.radians(14), 0))
HALO = (0.36, 0.55)


def srgb_to_linear(color):
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color)


def plastic(name, color, metal=False):
    """Vertex colour x part colour, glossy: a SmoothPlastic MeshPart under Realistic lighting;
    `metal` for the gold cap (MaterialVariant PetMetal in game)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.2 if not metal else 0.15
    bsdf.inputs["Metallic"].default_value = 1.0 if metal else 0.0
    bsdf.inputs["Coat Weight"].default_value = 0.0 if metal else 0.5
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


def neon(name, color, strength=3.0, alpha=1.0):
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


def dress(kit, bottom, look, scale=1.0, meteor=False):
    """One egg standing on `bottom`, as the game builds it."""
    pieces = {piece.name: piece for piece in kit}
    name, color, cap_color, seam_lit, window_lit, has_antenna, orbit, halo = look
    centre_at = bottom + Vector((0, 0, HALF_HEIGHT * scale))
    shell = METEOR_SHELL if meteor else PEARL
    place(pieces["Base"], "Base", centre_at, plastic("Base", shell), scale)
    if meteor:
        place(pieces["Cap"], "Cap", centre_at, plastic("Cap", shell), scale)
        place(pieces["Cracks"], "Cracks", centre_at, neon("Cracks", METEOR_GLOW), scale)
    else:
        place(pieces["Cap"], "Cap", centre_at, plastic("Cap", cap_color or PEARL, metal=cap_color is GOLD), scale)
    lit_seam = meteor or seam_lit
    glow = METEOR_GLOW if meteor else color
    place(pieces["Seam"], "Seam", centre_at, neon("Seam", glow, 2.5) if lit_seam else plastic("Seam", UNLIT), scale)
    lit_window = meteor or window_lit
    place(pieces["Window"], "Window", centre_at, neon("Window", glow, 2.5) if lit_window else plastic("Window", UNLIT), scale)
    if meteor:
        return
    if has_antenna:
        place(pieces["Antenna"], "Antenna", centre_at, plastic("Antenna", ROD), scale)
        place(pieces["Tip"], "Tip", centre_at, neon("Tip", color, 4.0), scale)
    if orbit:
        radius, turn = ORBIT
        place(pieces["Ring"], "Orbit", centre_at, neon("Orbit", color, 2.5, 0.85), radius * scale, turn)
    if halo:
        radius, gap = HALO
        place(pieces["Ring"], "Halo", centre_at + Vector((0, 0, (HALF_HEIGHT + gap) * scale)), neon("Halo", GOLD, 3.0), radius * scale)


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
    obj.data.materials.append(neon("Label", (0.75, 0.8, 0.95), 1.2))


def sheet(kit, path):
    for piece in kit:
        piece.hide_render = True
    spacing = 2.9
    row = 4.6
    for index, look in enumerate(LADDER):
        dress(kit, Vector((index * spacing, 0, row)), look)
        label(look[0], (index * spacing, -1.4, row - 0.75), 0.28)
    dress(kit, Vector((5 * spacing, 0, row)), LADDER[2], meteor=True)
    label("Метеоритное", (5 * spacing, -1.4, row - 0.75), 0.28)
    for name, scale, x in (("Маленькое", 0.65, 0.0), ("Среднее", 1.0, 2.4), ("Большое", 1.5, 5.6)):
        dress(kit, Vector((x, 0, 0)), LADDER[2], scale)
        label(name, (x, -1.4, -0.75), 0.28)
    for look, x in zip(LADDER[3:], (9.6, 13.6)):
        dress(kit, Vector((x, 0, 0)), look, 1.5)
        label(f"{look[0]}, большое", (x, -1.4, -0.75), 0.28)
    render(Vector((7.3, 0, row / 2 + 1.0)), path)


def render(target, path, size=(2700, 1500), distance=28):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(scene.eevee, attribute):
            setattr(scene.eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.25
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    # The camera sees dark space; reflections see a soft sky, as Roblox metal reflects its skybox
    # (without it the gold cap renders black).
    nodes, links = world.node_tree.nodes, world.node_tree.links
    dark = nodes.get("Background")
    dark.inputs["Color"].default_value = (0.006, 0.008, 0.025, 1.0)
    sky = nodes.new("ShaderNodeBackground")
    sky.inputs["Color"].default_value = (0.35, 0.4, 0.55, 1.0)
    sky.inputs["Strength"].default_value = 0.6
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
    camera.location = (target.x, -distance, target.z + 2.5)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Wrote", path)


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    kit = build()
    export(kit, os.path.join(OUT_DIR, "egg-kit.glb"))
    if SHEET:
        sheet(kit, os.path.join(OUT_DIR, "egg-kit.png"))
