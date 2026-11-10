# Concept renders for the central station (docs/plans/POLISH.md, queue item 3, "Station and bays"):
# the user wants it to look inviting and to call players over by itself, so that from their own
# island they see the coin board, the shops and the rest (2026-11-08; no separate pin, decision 069).
# Three directions, each a different silhouette over the same platform (StationSize: platform 60,
# dome 90, islands 95 under domes of 142.5 on a ring of 398.5; one stud is one Blender unit, Z up):
#
#   arena   - a four-sided scoreboard hangs from the dome's crown over a plaza, kiosks round it;
#   halo    - a ring floats round the dome with eight screens, one facing each island;
#   beacon  - a spire through the dome with a lamp and sweeping beams, the board on its sides.
#
# Each gets three pictures: from the player's own island (third-person camera behind them), close
# up on the platform, and from far out in space with the light column over the player's island.
# A draft for review, not the final look.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/station/concept_station.py -- <outdir> [direction ...] [--views far,near,space] [--fast]

import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import real  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FAST = "--fast" in ARGS
VIEWS = ["far", "near", "space"]
if "--views" in ARGS:
    VIEWS = ARGS[ARGS.index("--views") + 1].split(",")
POSITIONAL = [a for i, a in enumerate(ARGS) if not a.startswith("--") and (i == 0 or ARGS[i - 1] != "--views")]
OUT_DIR = os.path.abspath(POSITIONAL[0] if POSITIONAL else "out/station")
DIRECTIONS = POSITIONAL[1:] or ["arena", "halo", "beacon"]

# --- The station's size (StationSize, StationConfig) ---------------------------------------------

PLATFORM_RADIUS = 60
PLATFORM_THICKNESS = 4
RIM_WIDTH = 2
DOME_RADIUS = 90
ISLAND_RADIUS = 95
ISLAND_DOME_RADIUS = 142.5
ISLAND_COUNT = 8
ISLAND_RING = (2 * ISLAND_DOME_RADIUS + 20) / (2 * math.sin(math.pi / ISLAND_COUNT))
ISLAND_SPAWN = ISLAND_RADIUS * 0.6


def dome_rise(platform, dome):
    return math.sqrt(dome**2 - (platform + RIM_WIDTH) ** 2)


DOME_Z = dome_rise(PLATFORM_RADIUS, DOME_RADIUS)
DOME_TOP = DOME_Z + DOME_RADIUS
ISLAND_DOME_Z = dome_rise(ISLAND_RADIUS, ISLAND_DOME_RADIUS)

# The player's own island is the first one, on +X; the station's front faces it.
OWN = Vector((ISLAND_RING, 0, 0))

# --- Palette ---------------------------------------------------------------------------------------

CYAN = (0.25, 0.75, 1.0)
GOLD = (1.0, 0.72, 0.18)
MAGENTA = (1.0, 0.25, 0.75)
ORANGE = (1.0, 0.45, 0.12)
VIOLET = (0.55, 0.35, 1.0)
WHITE = (0.92, 0.95, 1.0)
TEAL = (0.2, 1.0, 0.75)

FONT = None


def font():
    global FONT
    if FONT is None:
        try:
            FONT = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
        except RuntimeError:
            FONT = False
    return FONT or None


# --- Materials ---------------------------------------------------------------------------------------

MATS = {}


def mat(key, make):
    if key not in MATS:
        MATS[key] = make()
    return MATS[key]


def hull_metal(name, color, panel=0.6):
    """Painted hull plating: panel seams in a grid, slight wear, a satin sheen."""
    m, nodes, links, bsdf = real._principled(name)
    coord = nodes.new("ShaderNodeTexCoord")
    brick = nodes.new("ShaderNodeTexBrick")
    brick.inputs["Scale"].default_value = 0.08
    brick.inputs["Mortar Size"].default_value = 0.012
    brick.inputs["Color1"].default_value = (*color, 1)
    brick.inputs["Color2"].default_value = (*(c * 0.82 for c in color), 1)
    brick.inputs["Mortar"].default_value = (*(c * panel * 0.5 for c in color), 1)
    links.new(coord.outputs["Object"], brick.inputs["Vector"])
    links.new(brick.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.75
    bsdf.inputs["Roughness"].default_value = 0.32
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    links.new(brick.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    m.diffuse_color = (*color, 1)
    return m


def soft_glow(name, colour, strength=2.0, density=0.5, fade_up=False, edge=False):
    """Light without a hard surface: a beam, a hologram, a dome. Bright where seen face-on and
    fading at the silhouette (or the other way round with `edge`, for a dome's shimmer); `fade_up`
    also fades it along the object's height (a light column dying out in the sky)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    nodes, links = m.node_tree.nodes, m.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*colour, 1)
    em.inputs["Strength"].default_value = strength
    facing = nodes.new("ShaderNodeLayerWeight")
    facing.inputs["Blend"].default_value = 0.5
    shape = nodes.new("ShaderNodeMath")
    shape.operation = "POWER"
    shape.inputs[1].default_value = 2.5 if edge else 2.0
    if edge:
        links.new(facing.outputs["Facing"], shape.inputs[0])
    else:
        inv = nodes.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        links.new(facing.outputs["Facing"], inv.inputs[1])
        links.new(inv.outputs[0], shape.inputs[0])
    amount = nodes.new("ShaderNodeMath")
    amount.operation = "MULTIPLY"
    amount.inputs[1].default_value = density
    links.new(shape.outputs[0], amount.inputs[0])
    result = amount
    if edge:
        base = nodes.new("ShaderNodeMath")
        base.operation = "ADD"
        base.inputs[1].default_value = 0.025
        links.new(amount.outputs[0], base.inputs[0])
        result = base
    if fade_up:
        coord = nodes.new("ShaderNodeTexCoord")
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coord.outputs["Generated"], sep.inputs[0])
        inv_z = nodes.new("ShaderNodeMath")
        inv_z.operation = "SUBTRACT"
        inv_z.inputs[0].default_value = 1.0
        links.new(sep.outputs["Z"], inv_z.inputs[1])
        curve = nodes.new("ShaderNodeMath")
        curve.operation = "POWER"
        curve.inputs[1].default_value = 1.6
        links.new(inv_z.outputs[0], curve.inputs[0])
        both = nodes.new("ShaderNodeMath")
        both.operation = "MULTIPLY"
        links.new(result.outputs[0], both.inputs[0])
        links.new(curve.outputs[0], both.inputs[1])
        result = both
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(result.outputs[0], mix.inputs["Fac"])
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(em.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs[0])
    return m


def screen(name, colour, strength=0.6):
    """A display's dark glowing glass."""
    m, nodes, links, bsdf = real._principled(name)
    bsdf.inputs["Base Color"].default_value = (0.01, 0.015, 0.03, 1)
    bsdf.inputs["Roughness"].default_value = 0.08
    bsdf.inputs["Emission Color"].default_value = (*colour, 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    return m


def floor_tiles(name):
    """The plaza's floor: big pale tiles with dark seams."""
    m, nodes, links, bsdf = real._principled(name)
    coord = nodes.new("ShaderNodeTexCoord")
    brick = nodes.new("ShaderNodeTexBrick")
    brick.inputs["Scale"].default_value = 0.12
    brick.inputs["Mortar Size"].default_value = 0.02
    brick.inputs["Color1"].default_value = (0.2, 0.22, 0.29, 1)
    brick.inputs["Color2"].default_value = (0.16, 0.18, 0.25, 1)
    brick.inputs["Mortar"].default_value = (0.1, 0.11, 0.16, 1)
    brick.offset = 0.0
    links.new(coord.outputs["Object"], brick.inputs["Vector"])
    links.new(brick.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.1
    bsdf.inputs["Roughness"].default_value = 0.6
    return m


def coin_metal():
    """Gold that reads as gold against black space: metal with a warm glow of its own (plain
    metal mirrors the dark sky and turns black)."""
    m = real.chrome("Coin", (1.0, 0.72, 0.25), 0.25)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.6, 0.15, 1)
    bsdf.inputs["Emission Strength"].default_value = 1.2
    return m


def station_dome(colour):
    """The station's own dome, tinted in its accent so it stands apart from the islands'."""
    return soft_glow("StationDome", colour, 1.6, 0.3, edge=True)


def M():
    """The shared materials, made once per scene."""
    return {
        "hull": mat("hull", lambda: hull_metal("Hull", (0.30, 0.33, 0.42))),
        "hull_dark": mat("hull_dark", lambda: hull_metal("HullDark", (0.12, 0.13, 0.19))),
        "hull_light": mat("hull_light", lambda: hull_metal("HullLight", (0.72, 0.75, 0.82))),
        "floor": mat("floor", lambda: floor_tiles("Floor")),
        "island_floor": mat("island_floor", lambda: hull_metal("IslandFloor", (0.22, 0.24, 0.30))),
        "dome": mat("dome", lambda: soft_glow("Dome", (0.45, 0.78, 1.0), 1.2, 0.22, edge=True)),
        "coin": mat("coin", lambda: coin_metal()),
        "awning": [
            mat(f"aw{i}", lambda c=c: real.gloss(f"Awning{i}", c, 0.35)) for i, c in enumerate(
                [(0.9, 0.42, 0.12), (0.45, 0.28, 0.9), (0.12, 0.7, 0.55), (0.85, 0.2, 0.55)])
        ],
        "rim": mat("rim", lambda: real.glow("Rim", CYAN, 4.0)),
        "gold": mat("gold", lambda: real.chrome("Gold", (1.0, 0.7, 0.25), 0.2)),
        "gold_glow": mat("gold_glow", lambda: real.glow("GoldGlow", GOLD, 5.0)),
        "magenta": mat("magenta", lambda: real.glow("Magenta", MAGENTA, 4.0)),
        "orange": mat("orange", lambda: real.glow("Orange", ORANGE, 4.0)),
        "violet": mat("violet", lambda: real.glow("Violet", VIOLET, 4.0)),
        "teal": mat("teal", lambda: real.glow("Teal", TEAL, 4.0)),
        "white": mat("white", lambda: real.glow("White", WHITE, 3.0)),
        "screen": mat("screen", lambda: screen("Screen", (0.1, 0.25, 0.6), 0.5)),
        "holo": mat("holo", lambda: soft_glow("Holo", CYAN, 3.0, 0.75)),
        "holo_gold": mat("holo_gold", lambda: soft_glow("HoloGold", GOLD, 3.0, 0.8)),
        "beam": mat("beam", lambda: soft_glow("Beam", (1.0, 0.85, 0.55), 1.8, 0.18)),
        "column": mat("column", lambda: soft_glow("Column", (0.3, 1.0, 0.8), 4.0, 0.9, fade_up=True)),
        "column_soft": mat("column_soft", lambda: soft_glow("ColumnSoft", (0.3, 1.0, 0.8), 2.5, 0.35, fade_up=True)),
        "people": [
            mat(f"p{i}", lambda c=c: real.gloss(f"P{i}", c, 0.4)) for i, c in enumerate(
                [(0.9, 0.3, 0.25), (0.2, 0.55, 0.95), (0.95, 0.8, 0.2), (0.3, 0.8, 0.4), (0.8, 0.4, 0.9)])
        ],
        "skin": mat("skin", lambda: real.gloss("Skin", (0.95, 0.78, 0.6), 0.5)),
        "pets": [
            mat(f"pet{i}", lambda c=c: real.gloss(f"Pet{i}", c, 0.2, 0.3)) for i, c in enumerate(
                [(0.3, 0.9, 0.6), (0.95, 0.5, 0.2), (0.4, 0.6, 1.0), (0.9, 0.3, 0.7), (0.95, 0.85, 0.3), (0.6, 0.4, 1.0)])
        ],
    }


# --- Primitives ----------------------------------------------------------------------------------


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def cylinder(location, radius, depth, material, rotation=(0, 0, 0), vertices=64, radius2=None):
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=radius2, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    smooth(obj)
    real.assign(obj, material)
    return obj


def box(location, size, material, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = size
    real.assign(obj, material)
    return obj


def ring(location, major, minor, material, rotation=(0, 0, 0), squash=1.0):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=location, rotation=rotation, major_segments=96, minor_segments=12)
    obj = bpy.context.active_object
    obj.scale = (1, 1, squash)
    smooth(obj)
    real.assign(obj, material)
    return obj


def ball(location, radius, material, subdivisions=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = bpy.context.active_object
    smooth(obj)
    real.assign(obj, material)
    return obj


def dome(center, radius, cut_z, material):
    """A dome's shell: its sphere above the platform only (the part below would need hiding)."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=center, segments=96, ring_count=48)
    obj = bpy.context.active_object
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, cut_z - center[2]), plane_no=(0, 0, 1), clear_inner=True)
    bm.to_mesh(obj.data)
    bm.free()
    smooth(obj)
    real.assign(obj, material)
    return obj


def text(body, location, angle, size, material, align="CENTER"):
    """Upright text facing the horizontal direction `angle` (radians from +X)."""
    bpy.ops.object.text_add(location=location, rotation=(math.radians(90), 0, angle + math.pi / 2))
    obj = bpy.context.active_object
    obj.data.body = body
    obj.data.align_x = align
    obj.data.align_y = "CENTER"
    obj.data.size = size
    obj.data.extrude = 0.02
    f = font()
    if f:
        obj.data.font = f
    real.assign(obj, material)
    return obj


def facing(angle):
    return Vector((math.cos(angle), math.sin(angle), 0)), Vector((-math.sin(angle), math.cos(angle), 0))


LEADERS = [("StarKid", "4.81M"), ("NovaFox", "3.92M"), ("Zyx_77", "2.10M"), ("cosmo_dan", "1.44M"), ("Lumi", "980K"), ("orbitBoy", "712K")]


def board(center, angle, width, height, m, rows=6, title="ТОП МОНЕТ", frame=None, tall=False):
    """A coin board facing `angle`: a dark glowing screen in a frame, a title and the leaders."""
    f, r = facing(angle)
    center = Vector(center)
    turn = (0, 0, angle + math.pi / 2)
    box(center - f * 0.6, (width + 1.4, 1.0, height + 1.4), m["hull_dark"], turn)
    box(center, (width, 0.2, height), m["screen"], turn)
    trim = frame or m["gold_glow"]
    for dz in (height / 2 + 0.7, -height / 2 - 0.7):
        box(center + Vector((0, 0, dz)) + f * 0.1, (width + 1.6, 0.4, 0.35), trim, turn)
    front = center + f * 0.15
    title_size = height * (0.12 if tall else 0.16)
    text(title, front + Vector((0, 0, height / 2 - title_size * 0.9)), angle, title_size, m["gold_glow"])
    row_h = (height - title_size * 2.2) / rows
    places = [m["gold_glow"], m["white"], m["orange"]]
    for i in range(rows):
        name, coins = LEADERS[i % len(LEADERS)]
        z = height / 2 - title_size * 2.0 - row_h * (i + 0.5)
        size = row_h * (0.62 if i < 3 else 0.5)
        colour = places[i] if i < 3 else m["white"]
        text(f"{i + 1}  {name}", front + Vector((0, 0, z)) - r * (width / 2 - width * 0.07), angle, size, colour, "LEFT")
        text(f"● {coins}", front + Vector((0, 0, z)) + r * (width / 2 - width * 0.07), angle, size, m["gold_glow"], "RIGHT")
    return center


def person(location, colour, m, facing_angle=0.0, scale=1.0):
    """A player for scale: about 5.5 studs tall."""
    x, y, z = location
    cylinder((x, y, z + 1.9 * scale), 0.75 * scale, 2.6 * scale, colour, vertices=16)
    ball((x, y, z + 4.0 * scale), 0.8 * scale, m["skin"], 2)
    cylinder((x, y, z + 0.6 * scale), 0.6 * scale, 1.2 * scale, m["hull_dark"], vertices=16)
    # A jetpack on the back.
    f, _ = facing(facing_angle)
    box(Vector((x, y, z + 2.3 * scale)) - f * 0.9 * scale, (0.9 * scale, 0.9 * scale, 1.6 * scale), m["hull_light"], (0, 0, facing_angle + math.pi / 2))


def kiosk(at, angle, sign, sign_mat, m, hologram=None, wide=10.0):
    """A shop stall facing `angle`: a counter, a back wall, an awning and a tall glowing sign."""
    f, r = facing(angle)
    at = Vector(at)
    turn = (0, 0, angle + math.pi / 2)
    awning = m["awning"][sum(map(ord, sign)) % len(m["awning"])]
    # Counter with a glowing strip, back wall, two posts and a coloured awning over it.
    box(at + Vector((0, 0, 1.6)), (wide, 2.2, 3.2), m["hull_light"], turn)
    box(at + Vector((0, 0, 2.2)) + f * 1.12, (wide - 0.6, 0.1, 0.5), sign_mat, turn)
    box(at - f * 3.2 + Vector((0, 0, 4.5)), (wide + 2, 0.8, 9.0), m["hull"], turn)
    for side in (-1, 1):
        box(at + r * side * (wide / 2 + 1.2) + f * 1.6 + Vector((0, 0, 4.2)), (0.5, 0.5, 8.4), m["hull_light"], turn)
    box(at - f * 0.8 + Vector((0, 0, 8.8)), (wide + 3.4, 5.6, 0.5), awning, turn)
    box(at + f * 2.0 + Vector((0, 0, 8.6)), (wide + 3.4, 0.25, 0.35), sign_mat, turn)
    # The sign above the awning, big enough to read from the plaza's far side.
    sign_at = at - f * 3.2 + Vector((0, 0, 12.0))
    box(sign_at - f * 0.3, (wide + 5, 0.8, 4.6), m["hull_dark"], turn)
    box(sign_at + Vector((0, 0, 2.5)), (wide + 5, 1.0, 0.3), sign_mat, turn)
    box(sign_at - Vector((0, 0, 2.5)), (wide + 5, 1.0, 0.3), sign_mat, turn)
    text(sign, sign_at + f * 0.2, angle, 2.6, sign_mat)
    if hologram:
        hologram(at + Vector((0, 0, 21.0)), angle)


def jetpack_holo(m, size=1.0):
    def make(at, angle):
        _, r = facing(angle)
        for side in (-1, 1):
            c = at + r * side * 1.6 * size
            cylinder(c, 1.3 * size, 5.0 * size, m["holo"], vertices=24)
            cylinder(c - Vector((0, 0, 4.0 * size)), 1.0 * size, 3.0 * size, m["holo_gold"], vertices=16, radius2=0.0, rotation=(math.pi, 0, 0))
        box(at, (1.4 * size, 1.4 * size, 4.4 * size), m["holo"], (0, 0, angle + math.pi / 2))
        ring(at - Vector((0, 0, 7.5 * size)), 5.0 * size, 0.18 * size, m["teal"])
    return make


def gem_holo(m, size=1.0):
    def make(at, angle):
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=3.2 * size, radius2=0, depth=4.0 * size, location=at - Vector((0, 0, 1.0 * size)), rotation=(math.pi, 0, 0))
        real.assign(bpy.context.active_object, m["holo_gold"])
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=3.2 * size, radius2=1.8 * size, depth=1.6 * size, location=at + Vector((0, 0, 1.8 * size)))
        real.assign(bpy.context.active_object, m["holo_gold"])
        ring(at - Vector((0, 0, 6.5 * size)), 5.0 * size, 0.18 * size, m["gold_glow"])
    return make


def coin_holo(m, size=1.0):
    def make(at, angle):
        cylinder(at, 4.5 * size, 0.9 * size, m["coin"], rotation=(math.pi / 2, 0, angle + math.pi / 2), vertices=48)
        ring(at, 4.5 * size, 0.35 * size, m["gold_glow"], rotation=(math.pi / 2, 0, angle + math.pi / 2))
        f, _ = facing(angle)
        ring(at + f * 0.5, 3.2 * size, 0.25 * size, m["gold_glow"], rotation=(math.pi / 2, 0, angle + math.pi / 2))
    return make


# --- The common station ---------------------------------------------------------------------------


def platform(m, dome_colour=(0.45, 0.78, 1.0)):
    """The central platform: the floor, its glowing rim, a plaza pattern and the dome."""
    cylinder((0, 0, -PLATFORM_THICKNESS / 2), PLATFORM_RADIUS, PLATFORM_THICKNESS, m["floor"], vertices=96)
    cylinder((0, 0, -PLATFORM_THICKNESS / 4 - 0.08), PLATFORM_RADIUS + RIM_WIDTH, PLATFORM_THICKNESS / 2, m["rim"], vertices=96)
    for radius in (18, 44):
        ring((0, 0, 0.02), radius, 0.35, m["rim"], squash=0.15)
    dome((0, 0, DOME_Z), DOME_RADIUS, 0.0, station_dome(dome_colour))
    # The spawn pad, on the side facing the player's island.
    cylinder((30, 0, 0.1), 4, 0.3, m["teal"], vertices=32)


def stepped_hull(m, steps, depth, lights_mat):
    """A hull under the platform in shrinking steps, a light strip at every step."""
    top = -PLATFORM_THICKNESS
    step_h = depth / steps
    for i in range(steps):
        radius = PLATFORM_RADIUS * (1 - (i + 1) / (steps + 1.4))
        z = top - step_h * (i + 0.5)
        cylinder((0, 0, z), radius + 6, step_h, m["hull"] if i % 2 == 0 else m["hull_dark"], vertices=96)
        ring((0, 0, z - step_h / 2 + 0.3), radius + 6.2, 0.4, lights_mat, squash=0.6)
    return top - depth


def cone_hull(m, depth, tip_radius, lights_mat, engines=8):
    top = -PLATFORM_THICKNESS
    cylinder((0, 0, top - depth / 2), PLATFORM_RADIUS + 1, depth, m["hull"], radius2=tip_radius, rotation=(0, 0, 0), vertices=96)
    hull = bpy.context.active_object
    hull.rotation_euler = (0, 0, 0)
    for frac in (0.25, 0.6):
        radius = PLATFORM_RADIUS + 1 - (PLATFORM_RADIUS + 1 - tip_radius) * frac
        ring((0, 0, top - depth * frac), radius + 0.3, 0.45, lights_mat, squash=0.6)
    bottom = top - depth
    for k in range(engines):
        a = k / engines * math.tau
        p = Vector((math.cos(a), math.sin(a), 0)) * tip_radius * 0.65 + Vector((0, 0, bottom - 1.5))
        cylinder(p, 2.2, 3.0, m["hull_dark"], vertices=24)
        cylinder(p - Vector((0, 0, 1.6)), 1.6, 0.3, m["orange"], vertices=24)
    return bottom


def spire_hull(m, depth, lights_mat):
    top = -PLATFORM_THICKNESS
    cylinder((0, 0, top - depth * 0.15), PLATFORM_RADIUS + 1, depth * 0.3, m["hull"], radius2=PLATFORM_RADIUS * 0.45, vertices=96)
    cylinder((0, 0, top - depth * 0.3 - depth * 0.35), PLATFORM_RADIUS * 0.45, depth * 0.7, m["hull_dark"], radius2=0.5, vertices=48)
    for frac, radius in ((0.3, PLATFORM_RADIUS * 0.45), (0.55, PLATFORM_RADIUS * 0.29), (0.8, PLATFORM_RADIUS * 0.13)):
        ring((0, 0, top - depth * frac), radius + 0.3, 0.5, lights_mat, squash=0.6)
    return top - depth


# --- Directions -----------------------------------------------------------------------------------


def arena(m):
    """A sports arena in space: a four-sided scoreboard hangs from the dome's crown on cables over
    a round plaza with a giant coin; kiosks under tall signs round the plaza."""
    platform(m, (1.0, 0.45, 0.85))
    stepped_hull(m, 4, 22, m["magenta"])
    # The scoreboard: four faces, one towards each quarter of the island ring.
    cube_z, half, h = 100, 26, 30
    box((0, 0, cube_z), (2 * half - 1, 2 * half - 1, h + 1), m["hull_dark"])
    for k in range(4):
        a = k * math.pi / 2
        f, _ = facing(a)
        board(Vector((0, 0, cube_z)) + f * half, a, 2 * half - 4, h - 3, m, rows=6)
    for z in (cube_z + h / 2 + 1.0, cube_z - h / 2 - 1.0):
        box((0, 0, z), (2 * half + 2, 2 * half + 2, 1.2), m["hull"])
        for k in range(4):
            f, _ = facing(k * math.pi / 2)
            box(Vector((0, 0, z)) + f * (half + 1.05), (0.4, 2 * half + 2.2, 0.5) if k % 2 == 0 else (2 * half + 2.2, 0.4, 0.5), m["magenta"])
    # Cables up to the crown, and a crown of light on top of the dome.
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        c = Vector((math.cos(a), math.sin(a), 0)) * half * 1.2
        top = cube_z + h / 2 + 1.6
        length = DOME_TOP - top
        cylinder(c + Vector((0, 0, top + length / 2)), 0.35, length, m["hull_light"], vertices=8)
    cylinder((0, 0, DOME_TOP + 1.5), 10, 3, m["hull"], vertices=48)
    ring((0, 0, DOME_TOP + 3.0), 10, 0.5, m["gold_glow"])
    cylinder((0, 0, DOME_TOP + 8), 0.8, 10, m["hull_light"], vertices=12)
    ball((0, 0, DOME_TOP + 13.5), 1.8, m["gold_glow"])
    # The plaza: a round stage with the coin above it.
    cylinder((0, 0, 0.8), 12, 1.6, m["hull"], vertices=64)
    ring((0, 0, 1.6), 12, 0.3, m["gold_glow"])
    coin_holo(m, 1.6)(Vector((0, 0, 14)), 0)
    coin_holo(m, 1.6)(Vector((0, 0, 14)), math.pi)
    cylinder((0, 0, 4.5), 3.0, 6, m["holo_gold"], vertices=32)
    # Kiosks round the plaza, facing the middle.
    kiosk(Vector((math.cos(math.pi - 0.75), math.sin(math.pi - 0.75), 0)) * 40, -0.75, "ДЖЕТПАКИ", m["orange"], m, jetpack_holo(m, 1.2))
    kiosk(Vector((math.cos(math.pi + 0.75), math.sin(math.pi + 0.75), 0)) * 40, 0.75, "МАГАЗИН", m["violet"], m, gem_holo(m, 1.2))
    kiosk(Vector((-1, 0, 0)) * 44, 0.0, "ЗАДАНИЯ", m["teal"], m)
    # Lamp posts round the plaza.
    for k in range(10):
        a = k / 10 * math.tau + 0.3
        p = Vector((math.cos(a), math.sin(a), 0)) * 54
        cylinder(p + Vector((0, 0, 4)), 0.3, 8, m["hull_light"], vertices=8)
        ball(p + Vector((0, 0, 8.4)), 0.7, m["white"], 2)


def halo(m):
    """A floating ring round the dome with eight screens, one facing each island, so every
    player sees the leaders from home; a market street of stalls under the dome."""
    platform(m, (0.35, 0.85, 1.0))
    cone_hull(m, 40, 16, m["rim"])
    ring_z, ring_r = 92, 94
    # The band: a short wide cylinder shell (outer wall, inner wall, top and bottom glow edges).
    cylinder((0, 0, ring_z), ring_r, 14, m["hull"], vertices=128)
    outer = bpy.context.active_object
    cylinder((0, 0, ring_z), ring_r - 3, 14.2, m["hull_dark"], vertices=128)
    inner = bpy.context.active_object
    mod = outer.modifiers.new("Hollow", "BOOLEAN")
    mod.object = inner
    mod.operation = "DIFFERENCE"
    bpy.context.view_layer.objects.active = outer
    bpy.ops.object.modifier_apply(modifier="Hollow")
    bpy.data.objects.remove(inner)
    for dz in (7.3, -7.3):
        ring((0, 0, ring_z + dz), ring_r + 0.1, 0.45, m["rim"], squash=0.6)
    for k in range(ISLAND_COUNT):
        a = k / ISLAND_COUNT * math.tau
        f, _ = facing(a)
        board(Vector((0, 0, ring_z)) + f * (ring_r + 0.6), a, 34, 11.5, m, rows=3, frame=m["rim"])
    # Four pylons hold the ring up from the platform's edge, leaning out.
    for k in range(4):
        a = math.pi / 8 + k * math.pi / 2 + math.pi / 8
        base = Vector((math.cos(a), math.sin(a), 0)) * (PLATFORM_RADIUS + 1) + Vector((0, 0, -3))
        tip = Vector((math.cos(a), math.sin(a), 0)) * (ring_r - 1.5) + Vector((0, 0, ring_z - 7))
        mid = (base + tip) / 2
        length = (tip - base).length
        cylinder(mid, 1.4, length, m["hull_light"], vertices=12)
        obj = bpy.context.active_object
        obj.rotation_euler = (tip - base).to_track_quat("Z", "Y").to_euler()
        for t in (0.3, 0.6, 0.9):
            ball(base + (tip - base) * t, 0.9, m["rim"], 2)
    # A market street: stalls on an arc facing the platform's middle, coloured awnings.
    stalls = [("ДЖЕТПАКИ", m["orange"], jetpack_holo(m, 1.1)), ("МАГАЗИН", m["violet"], gem_holo(m, 1.1)), ("ЗАДАНИЯ", m["teal"], None), ("ПОДАРОК", m["magenta"], None)]
    for i, (sign, colour, holo) in enumerate(stalls):
        a = math.radians(-75 + i * 50) + math.pi
        kiosk(Vector((math.cos(a), math.sin(a), 0)) * 42, a + math.pi, sign, colour, m, holo)
    # The board at street level too, for reading up close, facing the spawn.
    board(Vector((22, 30, 9)), -0.8, 16, 12, m, rows=6)
    box((22, 30, 1.5), (10, 2, 3), m["hull"], (0, 0, -0.8 + math.pi / 2))


def beacon(m):
    """A lighthouse: a spire through the top of the dome with a lamp and two sweeping beams; the
    board runs down the spire's four sides; kiosks round its foot. The hull mirrors the spire."""
    platform(m, (1.0, 0.75, 0.35))
    spire_hull(m, 90, m["gold_glow"])
    # The spire: a wide foot, a four-sided board section, then a tapering mast.
    cylinder((0, 0, 4), 14, 8, m["hull"], radius2=10, vertices=8)
    ring((0, 0, 8.2), 10.5, 0.4, m["gold_glow"])
    board_z, board_h, half = 42, 52, 8.5
    box((0, 0, board_z), (2 * half - 0.5, 2 * half - 0.5, board_h + 2), m["hull_dark"])
    for k in range(4):
        a = k * math.pi / 2
        f, _ = facing(a)
        board(Vector((0, 0, board_z)) + f * half, a, 2 * half - 2.5, board_h - 4, m, rows=8, tall=True)
    box((0, 0, 12), (2 * half - 0.5, 2 * half - 0.5, 8), m["hull"])
    cylinder((0, 0, board_z + board_h / 2 + 2), 12, 3, m["hull"], vertices=8)
    mast_from, mast_to = board_z + board_h / 2 + 3.5, DOME_TOP + 55
    cylinder((0, 0, (mast_from + mast_to) / 2), 7, mast_to - mast_from, m["hull_light"], radius2=2.5, vertices=8)
    for z in (95, 125, 155, 185):
        frac = (z - mast_from) / (mast_to - mast_from)
        ring((0, 0, z), 7 - 4.5 * frac + 0.3, 0.45, m["gold_glow"], squash=0.6)
    # The lamp and its beams (they would sweep round slowly, like a lighthouse's).
    lamp = Vector((0, 0, mast_to + 5))
    cylinder(lamp - Vector((0, 0, 2.5)), 5, 1.2, m["hull"], vertices=24)
    ball(lamp, 4.0, m["gold_glow"])
    ring(lamp, 6.5, 0.4, m["gold_glow"], rotation=(math.radians(90), 0, 0.6))
    for a in (0.55, 0.55 + math.pi):
        d = Vector((math.cos(a), math.sin(a), -0.08)).normalized()
        length = 520
        cylinder(lamp + d * length / 2, 3.0, length, m["beam"], radius2=26, vertices=32)
        bpy.context.active_object.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    # Kiosks round the foot.
    kiosk(Vector((math.cos(math.pi - 0.8), math.sin(math.pi - 0.8), 0)) * 36, -0.8, "ДЖЕТПАКИ", m["orange"], m, jetpack_holo(m, 1.2))
    kiosk(Vector((math.cos(math.pi + 0.8), math.sin(math.pi + 0.8), 0)) * 36, 0.8, "МАГАЗИН", m["violet"], m, gem_holo(m, 1.2))
    kiosk(Vector((-1, 0, 0)) * 40, 0.0, "ЗАДАНИЯ", m["teal"], m)


BUILDERS = {"arena": arena, "halo": halo, "beacon": beacon}


# --- Surroundings ---------------------------------------------------------------------------------


def islands(m, rng):
    """The ring of islands round the station: platforms, domes, hulls and pets standing on them.
    The light column rises over the player's own one."""
    for k in range(ISLAND_COUNT):
        a = k / ISLAND_COUNT * math.tau
        c = Vector((math.cos(a), math.sin(a), 0)) * ISLAND_RING
        cylinder(c - Vector((0, 0, PLATFORM_THICKNESS / 2)), ISLAND_RADIUS, PLATFORM_THICKNESS, m["island_floor"], vertices=96)
        cylinder(c - Vector((0, 0, PLATFORM_THICKNESS / 4 + 0.08)), ISLAND_RADIUS + RIM_WIDTH, PLATFORM_THICKNESS / 2, m["rim"], vertices=96)
        dome(c + Vector((0, 0, ISLAND_DOME_Z)), ISLAND_DOME_RADIUS, 0.0, m["dome"])
        for i in range(3):
            cylinder(c - Vector((0, 0, PLATFORM_THICKNESS + 4 + i * 8)), ISLAND_RADIUS * (0.85 - i * 0.22), 8, m["hull"], vertices=64)
        cylinder(c + Vector((0, 0, 0.6)), 9, 1.2, m["hull"], vertices=32)
        # Pets: a horseshoe of them round the incubator, open towards the station.
        inward = math.atan2(-c.y, -c.x)
        count = rng.randint(6, 20)
        for _ in range(count):
            t = rng.uniform(math.radians(30), math.radians(330)) + inward
            d = rng.uniform(22, ISLAND_RADIUS - 10)
            size = rng.uniform(1.2, 2.0) * (1 + 3 * (d / ISLAND_RADIUS) ** 2) * rng.uniform(0.6, 1.4)
            p = c + Vector((math.cos(t), math.sin(t), 0)) * d
            ball(p + Vector((0, 0, size)), size, rng.choice(m["pets"]), 2)
    # The light column over the player's own island.
    cylinder(OWN + Vector((0, 0, 450)), 14, 900, m["column_soft"], vertices=32)
    cylinder(OWN + Vector((0, 0, 450)), 2.2, 900, m["column"], vertices=16)


def space():
    """A dark sky with a faint violet and teal nebula and stars, like the game's skybox."""
    w = bpy.data.worlds.new("Space")
    bpy.context.scene.world = w
    w.use_nodes = True
    n, l = w.node_tree.nodes, w.node_tree.links
    bg = n.get("Background")
    coord = n.new("ShaderNodeTexCoord")
    noise = n.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.6
    noise.inputs["Detail"].default_value = 6.0
    l.new(coord.outputs["Generated"], noise.inputs["Vector"])
    ramp = n.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.4, (0.004, 0.004, 0.012, 1)
    els.new(0.6).color = (0.05, 0.02, 0.09, 1)
    els[1].position, els[1].color = 0.8, (0.02, 0.08, 0.12, 1)
    l.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    stars = n.new("ShaderNodeTexVoronoi")
    stars.inputs["Scale"].default_value = 260.0
    l.new(coord.outputs["Generated"], stars.inputs["Vector"])
    dot = n.new("ShaderNodeMath")
    dot.operation = "LESS_THAN"
    dot.inputs[1].default_value = 0.03
    l.new(stars.outputs["Distance"], dot.inputs[0])
    add = n.new("ShaderNodeMix")
    add.data_type = "RGBA"
    add.blend_type = "ADD"
    add.inputs["Factor"].default_value = 1.0
    l.new(ramp.outputs["Color"], add.inputs[6])
    l.new(dot.outputs[0], add.inputs[7])
    l.new(add.outputs[2], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0


def lights():
    """The sun 55° up (SkyLooks: ClockTime 10), warm, with a cool violet fill like the game's
    ambient light."""
    scene = bpy.context.scene
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy, sun.color, sun.angle = 2.6, (1.0, 0.93, 0.84), math.radians(1.5)
    obj = bpy.data.objects.new("Sun", sun)
    toward = Vector((-math.cos(math.radians(55)) * math.cos(0.5), math.cos(math.radians(55)) * math.sin(0.5), -math.sin(math.radians(55))))
    obj.rotation_euler = toward.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(obj)
    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy, fill.color = 0.6, (0.55, 0.5, 0.95)
    obj = bpy.data.objects.new("Fill", fill)
    obj.rotation_euler = Vector((0.6, -0.5, 0.3)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(obj)


VIEWPOINTS = {
    # From the player's own island: they stand at their spawn looking at the station, the camera
    # a dozen studs behind and above them (Roblox's default follow camera, 70° vertical).
    "far": dict(eye=OWN + Vector((-ISLAND_SPAWN + 16, 4, 9)), at=Vector((0, 0, 22)), lens=19),
    # Close up: a player who has just landed on the platform's front.
    "near": dict(eye=Vector((64, -16, 13)), at=Vector((0, 4, 36)), lens=16),
    # From far out in space, flying home: the station, the ring of islands and the column of light.
    "space": dict(eye=Vector((640, -860, 520)), at=Vector((90, 30, 10)), lens=24),
}


def render(name, view):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", not FAST), ("taa_render_samples", 16 if FAST else 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = (960, 540) if FAST else (1920, 1080)
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.4
    if hasattr(eevee, "shadow_pool_size"):
        eevee.shadow_pool_size = "1024"
    v = VIEWPOINTS[view]
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = v["lens"]
    cam_data.clip_end = 6000
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = v["eye"]
    cam.rotation_euler = (v["at"] - v["eye"]).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT_DIR, f"station_{name}_{view}.png")
    bpy.ops.render.render(write_still=True)
    print("Wrote", scene.render.filepath)
    bpy.data.objects.remove(cam)


def build(direction):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()
    global FONT
    FONT = None
    space()
    lights()
    m = M()
    BUILDERS[direction](m)
    islands(m, random.Random(7))
    # Light without a surface casts no shadow (domes, beams, holograms).
    for obj in bpy.context.scene.objects:
        slots = getattr(obj, "material_slots", [])
        if any(s.material and getattr(s.material, "surface_render_method", "") == "BLENDED" for s in slots):
            obj.visible_shadow = False
    # The player at their spawn on the own island, and a few on the station.
    person(OWN - Vector((ISLAND_SPAWN, 0, 0)), m["people"][1], m, math.pi)
    for i, (x, y, a) in enumerate(((48, -6, math.pi), (22, 12, -2.4), (-8, -20, 1.2), (14, -24, 2.0), (-24, 14, -0.6))):
        person((x, y, 0), m["people"][i % len(m["people"])], m, a)


for direction in DIRECTIONS:
    build(direction)
    for view in VIEWS:
        render(direction, view)
