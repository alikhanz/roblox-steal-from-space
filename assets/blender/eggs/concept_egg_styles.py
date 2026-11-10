# Concept sheet for the egg polish (docs/plans/POLISH.md, "Яйца"): three directions side by side,
# each with the five rarities and the meteor egg, to compare with free Toolbox eggs before
# choosing (user, 2026-11-08). Pets went robot sci-fi since the first egg concept (decision 074),
# so the eggs are tried in three looks:
#   Gloss   - the glossy candy egg of decision 072, a rarer egg wears more (spots, band, crown);
#   Capsule - a ceramic sci-fi capsule like the pets' hulls: a glowing seam, a window on the core;
#   Cosmic  - a tinted glass shell with a glowing core of nebula and stars inside.
# Glow sits in seams, windows and cores, never on the whole shell: a whole Neon shell burns to
# white under Bloom (BLENDER_ROBLOX.md, section 2).
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/eggs/concept_egg_styles.py -- <out.png> [styles|sizes]

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import real  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "concept_egg_styles.png"
SHEET = ARGS[1] if len(ARGS) > 1 else "styles"

# EggLooks.RARITIES, in linear-ish Blender colour
RARITIES = [
    ("Обычное", (0.80, 0.82, 0.88)),
    ("Необычное", (0.06, 0.72, 0.1)),
    ("Редкое", (0.03, 0.3, 1.0)),
    ("Эпическое", (0.5, 0.04, 1.0)),
    ("Легендарное", (1.0, 0.42, 0.0)),
]
METEOR_GLOW = (1.0, 0.36, 0.05)
GOLD = (1.0, 0.72, 0.28)
CERAMIC = (0.86, 0.87, 0.9)
DARK_GLASS = (0.02, 0.025, 0.04)

SPACING = 2.9
ROW_HEIGHT = 4.2
# A medium egg (EggLooks.EGG_SIZE): 1.6 wide, 2.1 tall, standing on z = 0.
HALF = Vector((0.8, 0.8, 1.05))
# How much narrower the top is than the bottom: a real egg, not a stretched ball.
TAPER = 0.11


# --- shape -----------------------------------------------------------------------------------


def radius_at(z, scale=1.0):
    """The egg's radius at height z above its bottom."""
    w = (z / scale - HALF.z) / HALF.z
    if abs(w) >= 1:
        return 0.0
    return HALF.x * scale * math.sqrt(1 - w * w) * (1 - TAPER * w)


def egg_mesh(name, location, mat, scale=1.0, inset=0.0, zmin=None, zmax=None):
    """An egg standing on `location`; `inset` shrinks it (a core inside a shell); zmin/zmax cut a
    band of it (height above the bottom, unscaled) - a cap, a base."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, location=(0, 0, 0), radius=1)
    obj = bpy.context.active_object
    obj.name = name
    for vertex in obj.data.vertices:
        w = vertex.co.z
        taper = 1 - TAPER * w
        vertex.co.x *= (HALF.x - inset) * taper
        vertex.co.y *= (HALF.y - inset) * taper
        vertex.co.z = (HALF.z - inset) * w + HALF.z
    if zmin is not None or zmax is not None:
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
    obj.scale = (scale, scale, scale)
    obj.location = location
    for poly in obj.data.polygons:
        poly.use_smooth = True
    real.assign(obj, mat)
    return obj


def ring(name, center, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=center, major_radius=major, minor_radius=minor, rotation=rotation, major_segments=64, minor_segments=12)
    obj = bpy.context.active_object
    obj.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = True
    real.assign(obj, mat)
    return obj


def sphere(name, center, size, mat, segments=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=center, radius=1)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    for poly in obj.data.polygons:
        poly.use_smooth = True
    real.assign(obj, mat)
    return obj


def cone(name, center, radius, depth, mat, rotation=(0, 0, 0), vertices=6):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, depth=depth, location=center, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    real.assign(obj, mat)
    return obj


def on_egg(base, angle, z, out=0.0, scale=1.0):
    """A point on the egg's surface: `angle` round from the front (-Y), `z` above the bottom."""
    r = radius_at(z, scale) + out
    return Vector((base.x + r * math.sin(angle), base.y - r * math.cos(angle), base.z + z))


def facing(angle, z, scale=1.0):
    """Euler rotation laying a flat thing on the surface at (angle, z): tilted by the slope."""
    dz = 0.01
    slope = (radius_at(z + dz, scale) - radius_at(z - dz, scale)) / (2 * dz)
    tilt = math.atan(slope)
    # Rx(90 deg) points the thing's local Z at the front (-Y); below the widest point the surface
    # faces down a little (slope > 0), so the tilt adds.
    return (math.radians(90) + tilt, 0, angle)


def glass(name, color, alpha):
    """See-through tinted glass as Roblox draws it (Glass / Transparency): blended, not refracted,
    so what is inside stays visible; a clear coat for the shine."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.04
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Alpha"].default_value = alpha
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    mat.diffuse_color = (*color, alpha)
    return mat


def lighter(color, amount):
    return tuple(c + (1 - c) * amount for c in color)


def darker(color, amount):
    return tuple(c * (1 - amount) for c in color)


# --- Gloss: the candy egg of decision 072 -----------------------------------------------------


def gloss_egg(base, tier, color, scale=1.0):
    shell = real.gloss(f"Gloss{tier}", color, roughness=0.12)
    egg_mesh("Egg", base, shell, scale)
    accent = real.gloss(f"GlossAccent{tier}", lighter(color, 0.65), roughness=0.15)
    if tier >= 1:
        for angle, z, size in ((0.45, 1.45, 0.15), (-0.35, 0.85, 0.18), (0.2, 0.5, 0.12), (-0.7, 1.4, 0.11), (0.9, 0.9, 0.13)):
            spot = sphere("Spot", on_egg(base, angle, z * scale, -0.035 * scale, scale), (size * scale, size * scale * 1.15, 0.06 * scale), accent)
            spot.rotation_euler = facing(angle, z * scale, scale)
    if tier >= 2:
        band = real.glow(f"Band{tier}", lighter(color, 0.5), 1.6)
        z = 1.0 * scale
        ring("Band", base + Vector((0, 0, z)), radius_at(z, scale) + 0.01 * scale, 0.065 * scale, band)
        star = real.glow("Star", (1.0, 1.0, 0.95), 4.0)
        for angle in (-0.75, 0.0, 0.75):
            point = on_egg(base, angle, z, 0.07 * scale, scale)
            for spin in (0, 45):
                cone("Star", point, 0.12 * scale, 0.03 * scale, star, (math.radians(90), 0, angle + math.radians(spin)), 4)
    if tier == 3:
        crystal = real.crystal("Crystal", lighter(color, 0.2), 1.5)
        top = 2.05 * scale
        for offset, tall, lean in ((-0.18, 0.34, 25), (0.0, 0.5, 0), (0.18, 0.34, -25)):
            cone("Crystal", base + Vector((offset * scale, 0, top + tall * scale / 2 - 0.05 * scale)), 0.09 * scale, tall * scale, crystal, (0, math.radians(lean), 0))
    if tier == 4:
        gold = real.chrome("Gold", GOLD, 0.12)
        top = 2.06 * scale
        bpy.ops.mesh.primitive_cylinder_add(radius=0.3 * scale, depth=0.14 * scale, location=base + Vector((0, 0, top)), vertices=24)
        real.assign(bpy.context.active_object, gold)
        for index in range(6):
            angle = math.radians(index * 60 + 90)
            cone("CrownTip", base + Vector((0.27 * scale * math.cos(angle), 0.27 * scale * math.sin(angle), top + 0.17 * scale)), 0.07 * scale, 0.22 * scale, gold)


def gloss_meteor(base, scale=1.0):
    egg_mesh("Egg", base, real.molten("Molten"), scale)


# --- Capsule: a ceramic sci-fi capsule, like the pets' hulls (decision 074) -------------------


def capsule_egg(base, tier, color, scale=1.0, meteor=False):
    seam_z = 1.18
    if meteor:
        body = real.molten("CapsuleMolten")
        cap = body
        seam = real.glow("MeteorSeam", METEOR_GLOW, 6.0)
    else:
        body = real.gloss("Ceramic", CERAMIC, roughness=0.22)
        if tier == 4:
            cap = real.chrome("CapGold", GOLD, 0.12)
        elif tier >= 1:
            cap = real.gloss(f"Cap{tier}", color, roughness=0.18)
        else:
            cap = body
        strength = (0.0, 1.5, 2.5, 3.0, 3.5)[tier]
        seam = real.glow(f"Seam{tier}", color, strength) if strength > 0 else real.gloss("SeamDark", (0.25, 0.26, 0.3))
    gap = 0.05
    egg_mesh("Base", base, body, scale, zmax=seam_z - gap)
    egg_mesh("Cap", base, cap, scale, zmin=seam_z + gap)
    # The seam: a glowing band set into the gap.
    egg_mesh("Seam", base, seam, scale, inset=0.012, zmin=seam_z - gap - 0.01, zmax=seam_z + gap + 0.01)
    # A foot ring, so it reads as a made thing standing on its base.
    foot = cap if tier == 4 else real.gloss("Foot", (0.32, 0.34, 0.4), roughness=0.3)
    if meteor:
        foot = body
    ring("Foot", base + Vector((0, 0, 0.16 * scale)), radius_at(0.16 * scale, scale) - 0.02 * scale, 0.06 * scale, foot)
    if tier >= 2 or meteor:
        # A porthole on the core: a dark rim round a window lit from inside.
        glow = METEOR_GLOW if meteor else lighter(color, 0.2)
        z = 0.7
        rim = sphere("Rim", on_egg(base, 0.0, z * scale, -0.05 * scale, scale), (0.25 * scale, 0.33 * scale, 0.08 * scale), real.gloss("Rim", (0.12, 0.13, 0.17), 0.2))
        rim.rotation_euler = facing(0.0, z * scale, scale)
        window = sphere("Window", on_egg(base, 0.0, z * scale, -0.035 * scale, scale), (0.19 * scale, 0.27 * scale, 0.07 * scale), real.glow("Window", glow, 2.5))
        window.rotation_euler = facing(0.0, z * scale, scale)
    if tier >= 3 and not meteor:
        # An antenna nub on top with a light.
        top = base + Vector((0, 0, 2.08 * scale))
        bpy.ops.mesh.primitive_cylinder_add(radius=0.035 * scale, depth=0.28 * scale, location=top + Vector((0, 0, 0.1 * scale)), vertices=12)
        real.assign(bpy.context.active_object, real.gloss("Antenna", (0.3, 0.32, 0.38)))
        sphere("Tip", top + Vector((0, 0, 0.27 * scale)), (0.07 * scale,) * 3, real.glow("Tip", color, 5.0))
        # A holographic ring orbiting the egg.
        ring("Orbit", base + Vector((0, 0, 1.15 * scale)), 1.08 * scale, 0.025 * scale, real.glow("Orbit", lighter(color, 0.3), 3.0), (math.radians(72), math.radians(14), 0))
    if tier == 4:
        ring("Halo", base + Vector((0, 0, 2.55 * scale)), 0.36 * scale, 0.04 * scale, real.glow("Halo", (1.0, 0.85, 0.45), 4.0))
        sparkles(base, scale, (1.0, 0.85, 0.5))


# --- Cosmic: a tinted glass shell with a glowing core inside ----------------------------------


def cosmic_egg(base, tier, color, scale=1.0, meteor=False):
    if meteor:
        egg_mesh("Core", base + Vector((0, 0, 0.16 * scale)), real.molten("CosmicMolten"), scale * 0.82)
        egg_mesh("Shell", base, glass("SmokedGlass", (0.08, 0.05, 0.04), 0.45), scale)
        return
    # The core: smaller egg of nebula, brighter with rarity; Common is a dim milky one.
    deep = darker(color, 0.8)
    mid = color
    bright = lighter(color, 0.6)
    stars = (0.0, 3.0, 5.0, 7.0, 9.0)[tier]
    if tier >= 1:
        core = real.nebula(f"Nebula{tier}", deep, mid, bright, stars)
        core.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value = 0.6 + 0.35 * tier
    else:
        core = real.frost("Milk", CERAMIC, 0.2)
    egg_mesh("Core", base + Vector((0, 0, 0.16 * scale)), core, scale * 0.82)
    egg_mesh("Shell", base, glass(f"Shell{tier}", lighter(color, 0.5), 0.22), scale)
    if tier >= 2:
        ring("Orbit", base + Vector((0, 0, 1.05 * scale)), radius_at(1.05 * scale, scale) + 0.16 * scale, 0.035 * scale, real.glow("Orbit", lighter(color, 0.3), 3.0), (math.radians(78), 0, 0))
    if tier >= 3:
        ring("Orbit2", base + Vector((0, 0, 1.05 * scale)), radius_at(1.05 * scale, scale) + 0.26 * scale, 0.025 * scale, real.glow("Orbit2", lighter(color, 0.4), 2.5), (math.radians(62), math.radians(35), 0))
    if tier == 4:
        ring("Halo", base + Vector((0, 0, 2.5 * scale)), 0.36 * scale, 0.04 * scale, real.glow("Halo", (1.0, 0.85, 0.45), 4.0))
        sparkles(base, scale, (1.0, 0.85, 0.5))


def sparkles(base, scale, color):
    mat = real.glow("Sparkle", color, 8.0)
    for angle, z, out in ((0.9, 1.9, 0.35), (-1.0, 1.5, 0.45), (1.5, 0.6, 0.4), (-0.5, 2.3, 0.2), (2.5, 1.2, 0.5), (-2.2, 0.8, 0.4)):
        sphere("Sparkle", on_egg(base, angle, min(z, 2.0) * scale, out * scale, scale) + Vector((0, 0, max(0, z - 2.0) * scale)), (0.045 * scale,) * 3, mat, 12)


# --- scenes ----------------------------------------------------------------------------------

STYLES = [
    ("Глянец", gloss_egg, lambda base, scale=1.0: gloss_meteor(base, scale)),
    ("Капсула", capsule_egg, lambda base, scale=1.0: capsule_egg(base, 2, METEOR_GLOW, scale, meteor=True)),
    ("Космос", cosmic_egg, lambda base, scale=1.0: cosmic_egg(base, 0, METEOR_GLOW, scale, meteor=True)),
]
COLUMNS = [name for name, _ in RARITIES] + ["Метеоритное"]


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
    real.assign(obj, real.glow("Label", (0.75, 0.8, 0.95), 1.2))


def pad(base, radius=0.85):
    """A plain dark disc under each egg, like a nest's bed."""
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=0.12, location=base - Vector((0, 0, 0.06)), vertices=48)
    real.assign(bpy.context.active_object, real.chrome("Pad", (0.05, 0.055, 0.08), 0.6))


def build_styles():
    for row, (title, make, meteor) in enumerate(STYLES):
        z = (len(STYLES) - 1 - row) * ROW_HEIGHT
        for tier, (_, color) in enumerate(RARITIES):
            base = Vector((tier * SPACING, 0, z))
            pad(base)
            make(base, tier, color)
        base = Vector((5 * SPACING, 0, z))
        pad(base)
        meteor(base)
        label(title, (-2.1, 0, z + 0.9), 0.42)
    for column, name in enumerate(COLUMNS):
        label(name, (column * SPACING, -1.0, -0.95), 0.3)
    return Vector((2.5 * SPACING - 0.6, 0, (len(STYLES) - 1) * ROW_HEIGHT / 2 + 1.0)), 2700, 2000, 30


def figure(base):
    """A rough player silhouette, 5 studs tall, for scale."""
    mat = real.gloss("Figure", (0.35, 0.37, 0.45), 0.5)
    for x in (-0.25, 0.25):
        bpy.ops.mesh.primitive_cube_add(size=1, location=base + Vector((x, 0, 1.0)))
        bpy.context.active_object.scale = (0.45, 0.45, 2.0)
        real.assign(bpy.context.active_object, mat)
    bpy.ops.mesh.primitive_cube_add(size=1, location=base + Vector((0, 0, 3.0)))
    bpy.context.active_object.scale = (1.0, 0.5, 2.0)
    real.assign(bpy.context.active_object, mat)
    for x in (-0.75, 0.75):
        bpy.ops.mesh.primitive_cube_add(size=1, location=base + Vector((x, 0, 3.0)))
        bpy.context.active_object.scale = (0.45, 0.45, 2.0)
        real.assign(bpy.context.active_object, mat)
    sphere("Head", base + Vector((0, 0, 4.5)), (0.55, 0.55, 0.5), mat)


SIZES = [("Маленькое", 0.65), ("Среднее", 1.0), ("Большое", 1.5)]


def build_sizes():
    """Each style's Rare egg in the three sizes (decision 084), next to a player."""
    x = 0.0
    for index, (title, make, _) in enumerate(STYLES):
        figure(Vector((x, 0.6, 0)))
        x += 1.7
        for name, scale in SIZES:
            x += 0.8 * scale + 0.25
            base = Vector((x, 0, 0))
            make(base, 2 + (index == 0) * 0, RARITIES[2][1], scale)
            x += 0.8 * scale + 0.25
        label(title, (x - 3.0, -1.0, -0.95), 0.36)
        x += 1.6
    right = x - 1.6
    return Vector(((right - 0.6) / 2, 0, 2.0)), 2700, 1000, 44


def render(target, width, height, distance):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = width, height
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
    sky.inputs["Strength"].default_value = 0.35
    texture = nodes.new("ShaderNodeTexSky")
    links.new(texture.outputs["Color"], sky.inputs["Color"])
    path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(sky.outputs["Background"], mix.inputs[1])
    links.new(dark.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], nodes.get("World Output").inputs["Surface"])

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        if name != "Key":
            data.specular_factor = 0.0
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (target.x - 9, -14, target.z + 10), 6000, 12, (1.0, 0.97, 0.92))
    area("Fill", (target.x + 14, -12, target.z + 1), 1600, 14, (0.75, 0.85, 1.0))
    area("Rim", (target.x, 12, target.z + 6), 7000, 24, (0.55, 0.65, 1.0))

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 50
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = (target.x, -distance, target.z + 3.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
render(*(build_sizes() if SHEET == "sizes" else build_styles()))
print("Wrote", OUT)
