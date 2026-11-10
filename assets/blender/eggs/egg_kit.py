# The egg's kit of meshes (docs/plans/POLISH.md, "Яйца"; decision 088): a space egg is a ceramic
# capsule like the pets' hulls and the station's kiosks (user, 2026-11-10: "мне нравятся больше
# капсулы, которые ты ранее показывал"). One GLB, one node per piece, all about the egg's centre
# (the origin).
#
# Built for phones (docs/design/BLENDER_ROBLOX.md, sections 3 and 7): an egg wears one piece per
# material class, not per detail, with its colours baked in the vertex colours (glTF COLOR_0;
# the game leaves the part white, so they show as they are):
#   Body<Rarity> - the plastic of the capsule: pearl base, the cap in the rarity's colour, the
#                  dark foot, window rim, unlit seam and window, the antenna's rod (SmoothPlastic);
#   Glow<Rarity> - all that glows: the lit seam, window, antenna tip, orbit, halo (Neon, coloured
#                  by the game in the rarity's colour; white in the vertex colours);
#   CapGold      - the legendary egg's cap: polished metal (PetMetal), its own material class;
#   Centre       - a speck at the egg's centre: the game measures where the others sit from it
#                  (World/EggKit); only in the kit, never worn.
# Rarities: Common, Uncommon, Rare, Epic, Legendary, and Meteor (a scorched capsule with lava in
# its seam, window and cracks; Common has no glow). Each shape is one MeshId copied on every egg of
# its kind. A medium egg is 1.6 x 2.1 x 1.6 studs (EggLooks.EGG_SIZE), its window facing -Y here
# (-Z, the look vector, in Roblox: measured in Studio).
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/eggs/egg_kit.py -- <outdir> [--sheet]
# Writes <outdir>/egg-kit.glb; with --sheet also <outdir>/egg-kit.png: the eggs as the game shows
# them, a check of the look before export.

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
# Shell resolution: smooth-shaded, a 2-stud egg reads round with 24 x 12.
SEGMENTS = 24
RINGS = 12
# The seam between base and cap: its middle (height from the centre) and half the gap.
SEAM_Z = 0.13
GAP = 0.05
# The window: height of its middle, its rim's and glass's half sizes (across, up, depth).
PORTHOLE_Z = -0.35
RIM = (0.25, 0.33, 0.08)
GLASS = (0.19, 0.27, 0.07)
# The antenna's rod and tip.
ANTENNA_TOP = HALF_HEIGHT - 0.02
# The orbit round epic and legendary eggs (radius, turn), the legendary halo (radius, gap above
# the top: clear of the antenna).
ORBIT = (1.1, (math.radians(72), math.radians(14), 0))
HALO = (0.36, 0.55)

# Baked colours, sRGB 0..255. The rarities' caps match their colours in EggLooks.RARITIES.
PEARL = (236, 239, 245)
UNLIT = (64, 66, 77)
ROD = (77, 82, 97)
FOOT = (94, 96, 102)
WINDOW_RIM = (60, 62, 70)
SCORCHED = (90, 58, 48)
SCORCHED_DARK = (45, 30, 26)
CAPS = {
    "Common": PEARL,
    "Uncommon": (71, 217, 107),
    "Rare": (64, 140, 255),
    "Epic": (173, 77, 255),
}
# What each rarity wears: lit seam, lit window, antenna and orbit, gold cap and halo.
LADDER = {
    "Common": dict(seam=False, window=False, antenna=False, halo=False),
    "Uncommon": dict(seam=True, window=False, antenna=False, halo=False),
    "Rare": dict(seam=True, window=True, antenna=False, halo=False),
    "Epic": dict(seam=True, window=True, antenna=True, halo=False),
    "Legendary": dict(seam=True, window=True, antenna=True, halo=True),
}


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


def paint(obj, rgb):
    """One baked colour (sRGB 0..255) for the whole object. Roblox reads glTF COLOR_0 as sRGB
    numbers, not linear: written through `color_srgb` (which the exporter stores linear) a cap
    came out darker and richer than the same Color3 next to it (Studio, 2026-11-10). So the sRGB
    numbers go into the attribute as they are."""
    mesh = obj.data
    attribute = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0)
    mesh.color_attributes.active_color = attribute
    return obj


WHITE = (255, 255, 255)


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
    return apply(obj)


def shell_band(zmin=None, zmax=None, inset=0.0):
    """The egg's shell between heights zmin and zmax (from the centre); `inset` shrinks it."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=SEGMENTS, ring_count=RINGS, radius=1)
    obj = bpy.context.active_object
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


def blob(centre, half, rotation):
    """A flattened ball (rim, glass) laid on the shell."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=6, radius=1, location=centre)
    obj = bpy.context.active_object
    obj.scale = half
    obj.rotation_euler = rotation
    return apply(smooth(obj))


def lower_shell():
    return shell_band(zmax=SEAM_Z - GAP)


def upper_shell():
    return shell_band(zmin=SEAM_Z + GAP)


def seam_band():
    return shell_band(zmin=SEAM_Z - GAP - 0.01, zmax=SEAM_Z + GAP + 0.01, inset=0.012)


def foot():
    z = -HALF_HEIGHT + 0.16
    bpy.ops.mesh.primitive_torus_add(location=(0, 0, z), major_radius=radius_at(z) - 0.02, minor_radius=0.06, major_segments=20, minor_segments=4)
    return apply(smooth(bpy.context.active_object))


def window_rim():
    return blob(front(PORTHOLE_Z, -0.06), RIM, facing_front(PORTHOLE_Z))


def window_glass():
    return blob(front(PORTHOLE_Z, -0.015), GLASS, facing_front(PORTHOLE_Z))


def rod():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=0.28, location=(0, 0, ANTENNA_TOP + 0.1), vertices=8)
    return apply(bpy.context.active_object)


def tip():
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(0, 0, ANTENNA_TOP + 0.27), segments=10, ring_count=5)
    return apply(smooth(bpy.context.active_object))


def ring(radius, location=(0, 0, 0), rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=0.03, major_segments=32, minor_segments=4, location=location, rotation=rotation)
    return apply(smooth(bpy.context.active_object))


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


def tube(points, radius):
    curve = bpy.data.curves.new("Crack", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 0
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, (angle, z) in zip(spline.points, points):
        point.co = (*on_shell(angle, z, radius * 0.2), 1.0)
    obj = new_object("Crack", curve)
    bpy.ops.object.select_all(action="DESELECT")
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
        parts.append(tube(main, 0.026))
        branch_at = main[rng.randrange(2, max(3, len(main) - 1))]
        branch = crack_path(rng, branch_at[0], branch_at[1], 4)
        if len(branch) > 1:
            parts.append(tube(branch, 0.018))
    return smooth(join("Cracks", parts))


# --- The kit -------------------------------------------------------------------------------------


def body(rarity):
    """The capsule's plastic for `rarity`: everything that does not glow, colours baked."""
    wears = LADDER[rarity]
    parts = [paint(lower_shell(), PEARL), paint(foot(), FOOT), paint(window_rim(), WINDOW_RIM)]
    if rarity != "Legendary":
        parts.append(paint(upper_shell(), CAPS[rarity]))
    if not wears["seam"]:
        parts.append(paint(seam_band(), UNLIT))
    if not wears["window"]:
        parts.append(paint(window_glass(), UNLIT))
    if wears["antenna"]:
        parts.append(paint(rod(), ROD))
    return join(f"Body{rarity}", parts)


def glow(rarity):
    """All that glows on `rarity`'s egg, one Neon piece (white: the game colours it)."""
    wears = LADDER[rarity]
    parts = []
    if wears["seam"]:
        parts.append(seam_band())
    if wears["window"]:
        parts.append(window_glass())
    if wears["antenna"]:
        radius, turn = ORBIT
        parts += [tip(), ring(radius, rotation=turn)]
    if wears["halo"]:
        radius, gap = HALO
        parts.append(ring(radius, location=(0, 0, HALF_HEIGHT + gap)))
    return paint(join(f"Glow{rarity}", parts), WHITE)


def meteor():
    base = join("BodyMeteor", [paint(lower_shell(), SCORCHED), paint(upper_shell(), SCORCHED),
                               paint(foot(), SCORCHED_DARK), paint(window_rim(), SCORCHED_DARK)])
    lava = paint(join("GlowMeteor", [seam_band(), window_glass(), cracks()]), WHITE)
    return [base, lava]


def gold_cap():
    obj = paint(upper_shell(), WHITE)
    obj.name = obj.data.name = "CapGold"
    return obj


def centre():
    bpy.ops.mesh.primitive_cube_add(size=0.02, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Centre"
    return paint(obj, WHITE)


# Piece names are the game's (World/EggKit, EggModel): keep them in step.
def build():
    pieces = [body(rarity) for rarity in LADDER]
    pieces += [glow(rarity) for rarity in LADDER if rarity != "Common"]
    pieces += meteor()
    pieces += [gold_cap(), centre()]
    for piece in pieces:
        # Each piece's origin is the egg's centre (see apply): the sheet wears copies there.
        assert piece.location.length < 1e-6, f"{piece.name} is not about the egg's centre"
    return pieces


def triangles(piece):
    return sum(len(p.vertices) - 2 for p in piece.data.polygons)


def export(pieces, path):
    """Every piece where the egg wears it, about the egg's centre (the origin): Studio keeps the
    nodes' places on import, so the kit in the place tells the game where each piece goes
    (World/EggKit, measured from `Centre`)."""
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    options = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=False, export_materials="NONE")
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    counts = {piece.name: triangles(piece) for piece in pieces}
    print("Wrote", path, len(pieces), "pieces", sum(counts.values()), "triangles", os.path.getsize(path), "bytes")
    print("Triangles:", ", ".join(f"{name} {count}" for name, count in counts.items()))
    for rarity in list(LADDER) + ["Meteor"]:
        worn = [f"Body{rarity}", f"Glow{rarity}"] + (["CapGold"] if rarity == "Legendary" else [])
        total = sum(counts.get(name, 0) for name in worn)
        print(f"  {rarity}: {total} triangles in {sum(1 for name in worn if name in counts)} parts")


# --- The check sheet: the eggs as the game shows them --------------------------------------------

# EggLooks.RARITIES colours (what the game paints the glow) and the gold cap (EggLooks.GOLD).
GLOW_COLORS = {
    "Uncommon": (120, 235, 130),
    "Rare": (90, 170, 255),
    "Epic": (200, 90, 255),
    "Legendary": (255, 200, 60),
    "Meteor": (255, 120, 30),
}
GOLD = (255, 190, 45)


def srgb_to_linear(rgb):
    return tuple((c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4 for c in rgb)


def baked():
    """Vertex colour as it is, glossy: a white SmoothPlastic MeshPart under Realistic lighting."""
    mat = bpy.data.materials.new("Baked")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.2
    bsdf.inputs["Coat Weight"].default_value = 0.5
    vertex = nodes.new("ShaderNodeVertexColor")
    vertex.layer_name = "Col"
    # The attribute holds sRGB numbers (see paint): back to linear for Blender's shading.
    gamma = nodes.new("ShaderNodeGamma")
    gamma.inputs["Gamma"].default_value = 2.2
    links.new(vertex.outputs["Color"], gamma.inputs["Color"])
    links.new(gamma.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def metal(rgb):
    mat = bpy.data.materials.new("Gold")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*srgb_to_linear(rgb), 1)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.15
    return mat


def neon(rgb, strength=2.5):
    mat = bpy.data.materials.new("Neon")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    linear = srgb_to_linear(rgb)
    bsdf.inputs["Base Color"].default_value = (*linear, 1)
    bsdf.inputs["Emission Color"].default_value = (*linear, 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def place(piece, location, mat, scale=1.0):
    copy = piece.copy()
    copy.data = piece.data.copy()
    copy.hide_render = False
    bpy.context.scene.collection.objects.link(copy)
    copy.location = location
    copy.scale = (scale, scale, scale)
    copy.data.materials.clear()
    copy.data.materials.append(mat)
    return copy


def dress(kit, bottom, rarity, scale=1.0):
    """One egg standing on `bottom`, as the game builds it (World/EggModel)."""
    centre_at = bottom + Vector((0, 0, HALF_HEIGHT * scale))
    place(kit[f"Body{rarity}"], centre_at, baked(), scale)
    if f"Glow{rarity}" in kit:
        place(kit[f"Glow{rarity}"], centre_at, neon(GLOW_COLORS[rarity]), scale)
    if rarity == "Legendary":
        place(kit["CapGold"], centre_at, metal(GOLD), scale)


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
    obj.data.materials.append(neon((190, 205, 242), 1.2))


NAMES = {"Common": "Обычное", "Uncommon": "Необычное", "Rare": "Редкое", "Epic": "Эпическое",
         "Legendary": "Легендарное", "Meteor": "Метеоритное"}


def sheet(pieces, path):
    kit = {piece.name: piece for piece in pieces}
    for piece in pieces:
        piece.hide_render = True
    spacing = 2.9
    row = 4.6
    for index, rarity in enumerate(list(LADDER) + ["Meteor"]):
        dress(kit, Vector((index * spacing, 0, row)), rarity)
        label(NAMES[rarity], (index * spacing, -1.4, row - 0.75), 0.28)
    for name, scale, x in (("Маленькое", 0.65, 0.0), ("Среднее", 1.0, 2.4), ("Большое", 1.5, 5.6)):
        dress(kit, Vector((x, 0, 0)), "Rare", scale)
        label(name, (x, -1.4, -0.75), 0.28)
    for rarity, x in (("Epic", 9.6), ("Legendary", 13.6)):
        dress(kit, Vector((x, 0, 0)), rarity, 1.5)
        label(f"{NAMES[rarity]}, большое", (x, -1.4, -0.75), 0.28)
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
