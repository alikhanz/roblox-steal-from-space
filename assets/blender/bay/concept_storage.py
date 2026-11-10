# Concept renders for the island's storage: where aliens with no place wait (today they stand
# small on a bare tray, BayLooks.PILE_*; user, 2026-11-10: "just models lying on the floor").
# A few directions, each holding the 24 aliens the island shows (BayConfig.FLOOR_SHOWN_MAX) at
# their floor size (the first guardian's, about 2 studs), beside a player-sized figure. A draft
# for review, not the final look.
#
# Studs = Blender units, +Z up. The storage faces -Y: toward the entrance's path, where the player
# walks in from the spawn. Palette: the station's steel and the pets' pearl (concept_station.py,
# concept_kiosks.py), linear.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/bay/concept_storage.py -- <outdir> [direction ...]
# Directions: shelf, combs, vitrine.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))

import bpy  # noqa: E402
import real  # noqa: E402
import robo_kinds  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/storage")
DIRECTIONS = ARGS[1:] or ["shelf", "combs", "vitrine"]

CELLS = 24
# A floor alien's width (BayLooks.PILE_ALIEN_SCALE: the first guardian's size, decision 068).
ALIEN_WIDTH = 1.9

STEEL = (0.30, 0.33, 0.42)
STEEL_LIGHT = (0.72, 0.75, 0.82)
STEEL_DARK = (0.12, 0.13, 0.19)
PEARL = (0.84, 0.86, 0.92)
NAVY = (0.035, 0.05, 0.12)


def srgb(r, g, b):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin(r), lin(g), lin(b))


# The storage's own zone colour, apart from places (blue), incubator (orange), trainer (yellow).
VIOLET = srgb(176, 128, 255)

# --- Materials ---------------------------------------------------------------------------------

_cache = {}


def mat(key, make):
    if key not in _cache:
        _cache[key] = make()
    return _cache[key]


def steel():
    return mat("steel", lambda: real.gloss("Steel", STEEL, roughness=0.32, metallic=0.35))


def steel_light():
    return mat("steelLight", lambda: real.gloss("SteelLight", STEEL_LIGHT, roughness=0.28, metallic=0.4))


def steel_dark():
    return mat("steelDark", lambda: real.chrome("SteelDark", STEEL_DARK, roughness=0.3))


def pearl():
    return mat("pearl", lambda: real.gloss("Pearl", PEARL, roughness=0.18))


def navy():
    return mat("navy", lambda: real.gloss("Navy", NAVY, roughness=0.25))


def glow(color, strength=4.0):
    return mat(("glow", color, strength), lambda: real.glow("Glow", color, strength * 0.7))


def glass():
    def make():
        # Roblox's Glass reads as a light, see-through tint: alpha-blended, not refracting.
        m, nodes, links, bsdf = real._principled("Glass")
        bsdf.inputs["Base Color"].default_value = (0.75, 0.88, 1.0, 1)
        bsdf.inputs["Roughness"].default_value = 0.05
        bsdf.inputs["Coat Weight"].default_value = 1.0
        bsdf.inputs["Emission Color"].default_value = (0.6, 0.7, 1.0, 1)
        bsdf.inputs["Emission Strength"].default_value = 0.08
        bsdf.inputs["Alpha"].default_value = 0.22
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        return m

    return mat("glass", make)


def floor_mat():
    return mat("floor", lambda: real.gloss("Floor", srgb(40, 46, 70), roughness=0.85, metallic=0.1))


# --- Shapes ------------------------------------------------------------------------------------


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


def rbox(name, size, location, material, bevel=0.15, rotation=(0, 0, 0), segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = min(bevel, min(size) * 0.49)
        mod.segments = segments
        mod.limit_method = "NONE"
        smooth(obj)
    real.assign(obj, material)
    return obj


def cyl(name, radius, depth, location, material, rotation=(0, 0, 0), vertices=48, radius2=None, bevel=0.0):
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(
            radius1=radius, radius2=radius2, depth=depth, location=location, rotation=rotation, vertices=vertices
        )
    obj = bpy.context.active_object
    obj.name = name
    if vertices > 8:
        smooth(obj)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
    real.assign(obj, material)
    return obj


def ring(name, major, minor, location, material, rotation=(0, 0, 0), segments=72):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, location=location, rotation=rotation, major_segments=segments, minor_segments=10
    )
    obj = bpy.context.active_object
    obj.name = name
    smooth(obj)
    real.assign(obj, material)
    return obj


def dome(name, radius, location, material):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=32, ring_count=16)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for vertex in obj.data.vertices:
        vertex.select = vertex.co.z < -1e-4
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    smooth(obj)
    real.assign(obj, material)
    return obj


def place(objects, matrix):
    for obj in objects:
        if obj.parent is None or obj.parent not in objects:
            obj.matrix_world = matrix @ obj.matrix_world


# --- Pets --------------------------------------------------------------------------------------

# A mix across the map, as a real storage holds (kind ids of robo_kinds.KINDS).
PET_KINDS = [k for k in robo_kinds.KINDS][::3]


def pet(index, location, yaw=0.0, width=ALIEN_WIDTH):
    """A pet of kind `index` (mod the mix) standing at `location`, facing -Y turned by `yaw`."""
    kind = PET_KINDS[(index * 7) % len(PET_KINDS)]
    before = set(bpy.data.objects)
    robo_kinds.build(kind, 1 + index % 3, 500, 0)
    bpy.context.view_layer.update()
    new = set(bpy.data.objects) - before
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    for obj in new:
        if obj.type != "MESH" or obj.hide_render:
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            low = Vector(map(min, low, world))
            high = Vector(map(max, high, world))
    span = max(high.x - low.x, high.y - low.y, 1e-3)
    k = width / span
    base = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    matrix = (
        Matrix.Translation(Vector(location))
        @ Matrix.Rotation(yaw, 4, "Z")
        @ Matrix.Scale(k, 4)
        @ Matrix.Translation(-base)
    )
    place(new, matrix)


# --- Directions --------------------------------------------------------------------------------


def shelf():
    """A. A collector's shelf: three tiers of eight lit niches, gently curved round the path."""
    columns, tiers = 8, 3
    cell_w, cell_h, depth = 2.5, 2.5, 2.3
    radius = 22.0
    base_h = 0.6
    arc = columns * cell_w / radius
    height = tiers * cell_h + base_h + 0.5

    def spot(a):
        """A point on the arc (its centre toward the viewer, so the shelf wraps round the path),
        the frame's turn there, and its facing (toward the arc's centre)."""
        x, y = radius * math.sin(a), -(radius - radius * math.cos(a))
        facing = Vector((-math.sin(a), -math.cos(a), 0))
        return x, y, (0, 0, -a), facing

    # Uprights between the niches; per niche a plinth, a crown, a back and three shelves.
    for c in range(columns + 1):
        x, y, rot, _ = spot(-arc / 2 + c * arc / columns)
        rbox("Upright", (0.32, depth + 0.2, height), (x, y, height / 2), pearl(), 0.12, rot)
    for c in range(columns):
        a = -arc / 2 + (c + 0.5) * arc / columns
        x, y, rot, facing = spot(a)
        back = facing * -(depth / 2 - 0.1)
        rbox("Plinth", (cell_w + 0.05, depth + 0.4, base_h), (x, y, base_h / 2), steel_dark(), 0.1, rot)
        top = base_h + tiers * cell_h + 0.25
        rbox("Crown", (cell_w + 0.05, depth + 0.3, 0.5), (x, y, top), steel(), 0.12, rot)
        strip = facing * ((depth + 0.3) / 2)
        rbox("CrownStrip", (cell_w + 0.06, 0.08, 0.12), (x + strip.x, y + strip.y, top), glow(VIOLET, 5), 0, rot)
        rbox("Back", (cell_w, 0.15, tiers * cell_h), (x + back.x, y + back.y, base_h + tiers * cell_h / 2), navy(), 0.05, rot)
        for t in range(tiers):
            z = base_h + t * cell_h
            rbox("Shelf", (cell_w, depth, 0.18), (x, y, z + 0.09), steel(), 0.06, rot)
            front = facing * (depth / 2 - 0.05)
            rbox("Lip", (cell_w - 0.3, 0.06, 0.08), (x + front.x, y + front.y, z + 0.2), glow(VIOLET, 4), 0, rot)
            # A soft light at the niche's top shines on the alien in it.
            rbox("Lamp", (cell_w - 0.6, 0.5, 0.05), (x, y, z + cell_h - 0.06), glow(srgb(220, 210, 255), 2.5), 0, rot)
            pet(c * tiers + t, (x, y, z + 0.18), -a)


def combs():
    """B. A honeycomb dock: a low plinth of 24 hex pads with lit rims, a backboard behind."""
    r = 1.38  # hex circumradius: flat-to-flat 2.39
    columns, rows = 6, 4
    dx, dy = r * math.sqrt(3), r * 1.5
    cells = []
    for row in range(rows):
        for col in range(columns):
            x = (col - (columns - 1) / 2) * dx + (dx / 2 if row % 2 else 0) - dx / 4
            y = (row - (rows - 1) / 2) * dy
            cells.append((x, y))
    width = columns * dx + dx / 2
    deep = rows * dy + r
    # The dock: a flat, rounded slab with a lit skirt.
    rbox("Dock", (width + 1.2, deep + 1.0, 0.45), (0, 0, 0.225), steel(), 0.3)
    rbox("Skirt", (width + 1.3, deep + 1.1, 0.08), (0, 0, 0.06), glow(VIOLET, 3), 0.04)
    for i, (x, y) in enumerate(cells):
        cyl("Pad", r - 0.12, 0.16, (x, y, 0.53), pearl(), (0, 0, math.radians(30)), vertices=6, bevel=0.05)
        ring("Rim", r - 0.2, 0.045, (x, y, 0.62), glow(VIOLET, 4), (0, 0, math.radians(30)), segments=6)
        pet(i, (x, y, 0.61), 0)
    # The backboard: a low curved panel with a light strip and the storage's emblem.
    back_y = deep / 2 + 1.0
    bend = 10.0
    for s in range(7):
        a = math.radians(-33 + s * 11)
        x, y = bend * math.sin(a), back_y - bend * (1 - math.cos(a))
        facing = Vector((-math.sin(a), -math.cos(a), 0))
        rbox("Board", (2.0, 0.4, 3.0), (x, y, 1.5), pearl(), 0.15, (0, 0, -a))
        strip = facing * 0.22
        rbox("BoardStrip", (1.9, 0.06, 0.14), (x + strip.x, y + strip.y, 2.6), glow(VIOLET, 5), 0, (0, 0, -a))


def vitrine():
    """C. Pedestals under glass on a stepped riser: three steps of eight, like a showcase."""
    steps, per = 3, 8
    pitch = 2.45
    for s in range(steps):
        z = 0.5 + s * 1.1
        y = s * 2.4
        width = per * pitch
        rbox("Step", (width + 0.8, 2.4, z), (0, y, z / 2), steel(), 0.15)
        rbox("StepLip", (width + 0.8, 0.07, 0.1), (0, y - 1.2, z - 0.08), glow(VIOLET, 4), 0)
        for i in range(per):
            x = (i - (per - 1) / 2) * pitch
            cyl("Pedestal", 0.95, 0.3, (x, y, z + 0.15), pearl(), vertices=32, bevel=0.06)
            ring("PedestalRing", 0.95, 0.05, (x, y, z + 0.28), glow(VIOLET, 4), segments=32)
            pet(s * per + i, (x, y, z + 0.3), 0, ALIEN_WIDTH * 0.85)
            # The glass cap: a short cylinder with a dome on it, one mesh per cap.
            cyl("CapWall", 1.0, 1.6, (x, y, z + 1.1), glass(), vertices=32)
            dome("CapTop", 1.0, (x, y, z + 1.9), glass())
            ring("CapRim", 1.0, 0.06, (x, y, z + 1.9), steel_light(), segments=32)


BUILDERS = {"shelf": shelf, "combs": combs, "vitrine": vitrine}
TITLES = {
    "shelf": "А. Стеллаж с нишами",
    "combs": "Б. Док-соты",
    "vitrine": "В. Пьедесталы под стеклом",
}

# --- Scene -------------------------------------------------------------------------------------


def space():
    w = bpy.data.worlds.new("Space")
    bpy.context.scene.world = w
    w.use_nodes = True
    n, l = w.node_tree.nodes, w.node_tree.links
    bg = n.get("Background")
    coord = n.new("ShaderNodeTexCoord")
    noise = n.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.0
    l.new(coord.outputs["Generated"], noise.inputs["Vector"])
    ramp = n.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.45, (0.006, 0.007, 0.02, 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.8, (0.05, 0.03, 0.1, 1)
    l.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    l.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0


def lights():
    scene = bpy.context.scene
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(3)
    sun.color = (1.0, 0.95, 0.88)
    obj = bpy.data.objects.new("Sun", sun)
    obj.rotation_euler = (math.radians(50), math.radians(-25), math.radians(-35))
    scene.collection.objects.link(obj)
    target = Vector((0, 0, 2))
    for name, location, energy, colour, size in (
        ("Fill", (22, -24, 8), 6000, (0.6, 0.7, 1.0), 18),
        ("Rim", (-6, 24, 14), 9000, (0.75, 0.6, 1.0), 20),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, colour
        data.specular_factor = 0.0
        light = bpy.data.objects.new(name, data)
        light.location = location
        light.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)


def figure(x, y, yaw):
    skin = mat("skin", lambda: real.gloss("Skin", srgb(245, 205, 150), roughness=0.5))
    shirt = mat("shirt", lambda: real.gloss("Shirt", srgb(70, 110, 200), roughness=0.6))
    pants = mat("pants", lambda: real.gloss("Pants", srgb(40, 45, 60), roughness=0.6))
    before = set(bpy.data.objects)
    rbox("LegL", (0.9, 0.9, 2.0), (-0.48, 0, 1.0), pants, 0.12)
    rbox("LegR", (0.9, 0.9, 2.0), (0.48, 0, 1.0), pants, 0.12)
    rbox("Torso", (2.0, 1.0, 2.0), (0, 0, 3.0), shirt, 0.15)
    rbox("ArmL", (0.9, 0.9, 2.0), (-1.48, 0, 3.0), skin, 0.12)
    rbox("ArmR", (0.9, 0.9, 2.0), (1.48, 0, 3.0), skin, 0.12)
    rbox("Head", (1.15, 1.15, 1.15), (0, 0, 4.6), skin, 0.3)
    rbox("Pack", (1.4, 0.7, 1.7), (0, -0.85, 3.1), steel_light(), 0.25)
    place(set(bpy.data.objects) - before, Matrix.Translation((x, y, 0)) @ Matrix.Rotation(yaw, 4, "Z"))


def label(body, location, size):
    curve = bpy.data.curves.new("Label", "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = "CENTER"
    try:
        curve.font = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
    except RuntimeError:
        pass
    obj = bpy.data.objects.new("Label", curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.rotation_euler = (math.radians(75), 0, 0)
    obj.location = location
    real.assign(obj, glow((0.8, 0.85, 1.0), 1.4))


def render(name, camera_at, look_at, lens=32, size=(1920, 1080)):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 48)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = 0.1
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = lens
    cam_data.clip_end = 2000
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = camera_at
    cam.rotation_euler = (Vector(look_at) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT_DIR, f"storage_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("Wrote", scene.render.filepath)


def build(direction):
    _cache.clear()
    space()
    lights()
    cyl("Floor", 40, 1.0, (0, 4, -0.5), floor_mat(), vertices=96)
    BUILDERS[direction]()
    # The player walks in toward it, a few studs off.
    figure(-7, -8, math.radians(-25))
    label(TITLES[direction], Vector((0, 6, 11.5)), 1.1)


for direction in DIRECTIONS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build(direction)
    # The game's camera: behind and above the player who walks up to it.
    render(direction, (-9, -22, 10.5), (0, 0, 2.2), 30)
    # Close, at an alien's height: how the aliens read in it.
    render(direction + "_near", (5, -9, 4.5), (0, 1, 1.8), 32, (1280, 1080))
