# Concept renders for the island incubator's capsules (docs/plans/POLISH.md, "Станция и отсеки";
# user, 2026-11-09: the capsules "look weak", to redo after the eggs). A few directions, each the
# same scene: the incubator in the island's centre with 6 bought capsules of its 12 (the rest shown
# as closed sockets), eggs of all three sizes (decision 084) and rarities from the real egg kit
# (assets/blender/eggs/egg_kit.py, decision 088), one egg ready to hatch, and where the timer chip
# and the "Hatch" prompt hang. A draft for review, not the final look.
#
# Studs = Blender units, +Z up. The entrance is -Y: the player walks in from there. Palette: the
# station's steel and the pets' pearl (concept_storage.py), linear.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/bay/concept_incubator.py -- <outdir> [direction ...]
# Directions: bell, cradle, greenhouse.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "eggs"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import egg_kit  # noqa: E402
import real  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/incubator")
DIRECTIONS = ARGS[1:] or ["bell", "cradle", "greenhouse"]

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


# The incubator's zone colour (BayLooks.INCUBATOR_COLOR) while an egg warms; the hatch action's
# green (DESIGN.md: "вылупить — зелёный") once it is ready.
WARM = srgb(255, 170, 60)
READY = srgb(90, 240, 110)

# The capsules' ring (BayLooks.CAPSULE_RING_RADIUS is 8.5 today; a little wider for the larger
# capsules) and the stand under them.
RING = 9.0
POSITIONS = 12
DAIS_RADIUS = 11.4
DAIS_HEIGHT = 0.6

# What each capsule holds, in the game's order (the first faces the entrance, the next ones
# alternate to either side): (rarity, size scale, state). "empty" is bought with no egg; past the
# list the slots are not bought.
SLOTS = [
    ("Legendary", 1.5, "ready"),
    ("Rare", 1.0, "warm"),
    ("Uncommon", 0.65, "warm"),
    ("Epic", 1.0, "warm"),
    ("Common", 1.5, "warm"),
    (None, 0, "empty"),
]
TIMERS = {2: "3:39", 3: "0:52", 4: "12:05", 5: "1:07:30"}

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


def glass(tint=(0.75, 0.88, 1.0), alpha=0.18):
    def make():
        # Roblox's Glass reads as a light, see-through tint: alpha-blended, not refracting.
        m, nodes, links, bsdf = real._principled("Glass")
        bsdf.inputs["Base Color"].default_value = (*tint, 1)
        bsdf.inputs["Roughness"].default_value = 0.05
        bsdf.inputs["Coat Weight"].default_value = 1.0
        bsdf.inputs["Emission Color"].default_value = (*tint, 1)
        bsdf.inputs["Emission Strength"].default_value = 0.06
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        return m

    return mat(("glass", tint, alpha), make)


def floor_mat():
    return mat("floor", lambda: real.gloss("Floor", srgb(40, 46, 70), roughness=0.85, metallic=0.1))


def state_color(state):
    return READY if state == "ready" else WARM


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


def ball(name, radius, location, material, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=32, ring_count=16)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    smooth(obj)
    real.assign(obj, material)
    return obj


def dome(name, radius, location, material, squash=1.0):
    """The upper half of a sphere, its rim at `location`."""
    obj = ball(name, radius, location, material, (1, 1, squash))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def lathe(name, profile, material, segments=48):
    """A solid of revolution about Z through (0, 0): `profile` is [(radius, z), ...] from bottom to
    top; a radius of 0 closes the end."""
    bm = bmesh.new()
    rings = []
    for radius, z in profile:
        ring_verts = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring_verts.append(bm.verts.new((radius * math.cos(a), radius * math.sin(a), z)))
        rings.append(ring_verts)
    for low, high in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((low[i], low[j], high[j], high[i]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    smooth(obj)
    real.assign(obj, material)
    return obj


def blade(name, path, widths, thickness, side, material):
    """A curved flat blade along `path` (points), `widths` across it along `side` (a unit vector),
    `thickness` through it; ends closed."""
    bm = bmesh.new()
    slices = []
    for index, point in enumerate(path):
        ahead = path[min(index + 1, len(path) - 1)] - path[max(index - 1, 0)]
        normal = ahead.cross(side).normalized()
        half_w = side * widths[index] / 2
        half_t = normal * thickness / 2
        slices.append([bm.verts.new(point + s * half_w + t * half_t) for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for low, high in zip(slices, slices[1:]):
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((low[i], low[j], high[j], high[i]))
    bm.faces.new(slices[0][::-1])
    bm.faces.new(slices[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = thickness * 0.45
    mod.segments = 3
    smooth(obj)
    real.assign(obj, material)
    return obj


def move(objects, matrix):
    for obj in objects:
        if obj.parent is None or obj.parent not in objects:
            obj.matrix_world = matrix @ obj.matrix_world


def built(make):
    """Runs `make` and returns the objects it added."""
    before = set(bpy.data.objects)
    make()
    return set(bpy.data.objects) - before


# --- Eggs (the real kit) -------------------------------------------------------------------------

_kit = {}


def egg(bottom, rarity, scale, yaw):
    """An egg of the kit standing on `bottom`, its window turned to face `yaw` (World/EggModel)."""
    if not _kit:
        for piece in egg_kit.build():
            piece.hide_render = True
            _kit[piece.name] = piece
    centre = Vector(bottom) + Vector((0, 0, egg_kit.HALF_HEIGHT * scale))
    pieces = [(f"Body{rarity}", egg_kit.baked())]
    if f"Glow{rarity}" in _kit:
        pieces.append((f"Glow{rarity}", egg_kit.neon(egg_kit.GLOW_COLORS[rarity])))
    if rarity == "Legendary":
        pieces.append(("CapGold", egg_kit.metal(egg_kit.GOLD)))
    for name, material in pieces:
        copy = egg_kit.place(_kit[name], centre, material, scale)
        copy.rotation_euler = (0, 0, yaw)


def egg_height(scale, rarity):
    """How tall an egg stands with what it wears (the legendary's halo)."""
    top = 2 * egg_kit.HALF_HEIGHT * scale
    if rarity == "Legendary":
        top += (egg_kit.HALO[1] + 0.05) * scale
    return top


# --- Labels: the chip over an egg and the prompt under it ------------------------------------------


def text(body, location, size, material, rotation=(math.radians(80), 0, 0)):
    curve = bpy.data.curves.new("Text", "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    try:
        curve.font = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
    except RuntimeError:
        pass
    obj = bpy.data.objects.new("Text", curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.rotation_euler = rotation
    obj.location = location
    real.assign(obj, material)
    return obj


def chip(location, words, color):
    """A world chip (UI/WorldChip): a dark glass pill with a dot and the words, facing the
    entrance."""
    x, y, z = location
    width = 0.42 * len(words) + 0.9
    rbox("Chip", (width, 0.08, 0.72), (x, y, z), navy(), bevel=0.34, rotation=(math.radians(-10), 0, 0))
    ball("Dot", 0.13, (x - width / 2 + 0.38, y - 0.08, z), glow(color, 5))
    text(words, (x + 0.2, y - 0.1, z), 0.5, glow((0.92, 0.95, 1.0), 1.6))


def prompt(location):
    """The hatch prompt (UI/GrabPrompt): a green pill with a round key badge and the word."""
    x, y, z = location
    rbox("Prompt", (3.6, 0.1, 1.0), (x, y, z), glow(srgb(40, 120, 60), 1.0), bevel=0.48)
    ball("Key", 0.36, (x - 1.3, y - 0.1, z), glow((0.9, 1.0, 0.9), 1.5), (1, 0.3, 1))
    text("E", (x - 1.3, y - 0.22, z), 0.42, navy())
    text("Вылупить", (x + 0.35, y - 0.12, z), 0.5, glow((0.95, 1.0, 0.95), 1.8))


# --- The incubator under every direction: a dais with a heater core and pipes to the slots ----------


def slot_angle(index):
    """Capsule `index` (1-based): the first faces the entrance, the next alternate to either side
    (BayModel.capsuleAngle)."""
    step = 2 * math.pi / POSITIONS
    offset = math.ceil((index - 1) / 2) * (1 if index % 2 == 0 else -1)
    return offset * step


def slot_frame(index):
    """The capsule's frame on the dais: its local -Y faces out of the ring."""
    a = slot_angle(index)
    at = Vector((RING * math.sin(a), -RING * math.cos(a), DAIS_HEIGHT))
    return Matrix.Translation(at) @ Matrix.Rotation(a, 4, "Z"), a


def dais(core=True):
    lathe(
        "Dais",
        [(0, 0), (DAIS_RADIUS - 0.4, 0), (DAIS_RADIUS, 0.15), (DAIS_RADIUS, DAIS_HEIGHT - 0.12),
         (DAIS_RADIUS - 0.25, DAIS_HEIGHT), (0, DAIS_HEIGHT)],
        steel(),
        96,
    )
    ring("DaisLight", DAIS_RADIUS - 0.05, 0.07, (0, 0, DAIS_HEIGHT * 0.55), glow(WARM, 3.5), segments=128)
    ring("DaisRim", DAIS_RADIUS - 0.35, 0.09, (0, 0, DAIS_HEIGHT), pearl(), segments=128)
    if not core:
        return
    # The heater in the middle: low, so the places behind the incubator stay in view.
    lathe("Core", [(0, 0), (2.6, 0), (2.6, 0.5), (2.2, 1.4), (1.4, 1.9), (0, 2.0)], pearl(), 64)
    move([lathe("CoreBand", [(2.62, 0.62), (2.48, 0.98), (2.46, 1.0), (2.6, 0.64)], glow(WARM, 4), 64)],
         Matrix.Translation((0, 0, DAIS_HEIGHT)))
    for obj in [bpy.data.objects["Core"]]:
        obj.location.z = DAIS_HEIGHT
    ring("CoreTop", 0.9, 0.12, (0, 0, DAIS_HEIGHT + 1.95), glow(WARM, 5))
    # A pipe to every slot, bought or not: the machine is whole from the start.
    for index in range(1, POSITIONS + 1):
        a = slot_angle(index)
        direction = Vector((math.sin(a), -math.cos(a), 0))
        start, end = 2.6, RING - 1.9
        mid = direction * (start + end) / 2 + Vector((0, 0, DAIS_HEIGHT + 0.18))
        length = end - start
        cyl("Pipe", 0.22, length, mid, steel_light(), rotation=(math.radians(90), 0, a), vertices=16)
        lit = index <= len(SLOTS) and SLOTS[index - 1][2] != "empty"
        if lit:
            cyl("PipeLight", 0.07, length, mid + Vector((0, 0, 0.2)), glow(state_color(SLOTS[index - 1][2]), 3),
                rotation=(math.radians(90), 0, a), vertices=8)


def fill(capsule, socket):
    """Every slot: a capsule (bought) with its egg, or a closed socket."""
    for index in range(1, POSITIONS + 1):
        frame, a = slot_frame(index)
        if index <= len(SLOTS):
            rarity, scale, state = SLOTS[index - 1]
            objects = built(lambda: capsule(state, rarity, scale))
            move(objects, frame)
            if rarity:
                floor = capsule.egg_floor + (capsule.hover if state else 0)
                egg(frame @ Vector((0, 0, floor)), rarity, scale, a)
        else:
            move(built(socket), frame)


def labels(capsule):
    """Chips over the capsules seen from the entrance, the prompt under the ready egg."""
    for index in range(1, 6):
        frame, a = slot_frame(index)
        rarity, scale, state = SLOTS[index - 1]
        top = frame @ Vector((0, 0, capsule.top(scale, rarity)))
        if state == "ready":
            chip((top.x, top.y - 0.3, top.z + 0.75), "Готово!", READY)
            front = frame @ Vector((0, -2.6, 0.9))
            prompt((front.x, front.y, front.z))
        elif index in TIMERS:
            chip((top.x, top.y - 0.3, top.z + 0.75), TIMERS[index], WARM)


# --- Direction A: a glass bell on a ceramic pedestal ------------------------------------------------


def bell(state, rarity, scale):
    light = glow(state_color(state), 5 if state == "ready" else 3.5)
    lathe("Pedestal", [(0, 0), (1.95, 0), (2.05, 0.3), (1.9, 0.75), (1.75, 0.85), (0, 0.85)], pearl())
    cyl("Plate", 1.6, 0.1, (0, 0, 0.88), steel_dark())
    ring("Heater", 1.45, 0.08, (0, 0, 0.92), light)
    ring("Collar", 1.82, 0.14, (0, 0, 0.92), steel_light())
    # The bell: room for a large legendary egg with its orbits and halo.
    tint = (0.75, 1.0, 0.8) if state == "ready" else (0.75, 0.88, 1.0)
    cyl("Bell", 1.75, 3.9, (0, 0, 0.92 + 1.95), glass(tint), vertices=48)
    dome("BellTop", 1.75, (0, 0, 0.92 + 3.9), glass(tint), squash=0.55)
    ring("Crown", 1.0, 0.16, (0, 0, 0.92 + 3.9 + 0.82), steel_light())
    ball("Lamp", 0.32, (0, 0, 0.92 + 3.9 + 1.0), light)
    for side in (-1, 1):
        rbox("Rib", (0.22, 0.22, 3.9), (side * 1.78, 0, 0.92 + 1.95), steel_light(), bevel=0.09)


bell.egg_floor = 0.95
bell.hover = 0.0
bell.top = lambda scale, rarity: 0.92 + 3.9 + 1.4


def bell_socket():
    lathe("Pedestal", [(0, 0), (1.95, 0), (2.05, 0.3), (1.9, 0.75), (1.75, 0.85), (0, 0.85)], pearl())
    dome("Lid", 1.6, (0, 0, 0.85), steel(), squash=0.4)
    ball("Lamp", 0.16, (0, 0, 0.85 + 0.66), steel_dark())


# --- Direction B: an open cradle, a bud of three ceramic petals ----------------------------------

PETAL_ANGLES = (math.radians(60), math.radians(180), math.radians(300))


def cradle(state, rarity, scale):
    light = glow(state_color(state), 5 if state == "ready" else 3.5)
    lathe("Socket", [(0, 0), (1.9, 0), (2.0, 0.25), (1.6, 0.9), (1.35, 1.0), (0, 1.0)], pearl())
    lathe("Plate", [(0, 1.0), (1.3, 1.0), (1.2, 1.12), (0, 1.12)], steel_dark())
    ring("Heater", 1.05, 0.09, (0, 0, 1.14), light)
    # The egg hovers over the heater; a ring of light under it.
    ring("Halo", 0.75 * max(scale, 0.8), 0.05, (0, 0, 1.3), light)
    for angle in PETAL_ANGLES:
        # -Y is out of the ring: no petal stands before the egg's window.
        out = Vector((math.sin(angle), -math.cos(angle), 0))
        side = Vector((-out.y, out.x, 0))
        path, widths = [], []
        steps = 14
        for i in range(steps + 1):
            t = i / steps
            radius = 1.55 + 0.75 * math.sin(t * math.pi * 0.85) - 0.35 * t
            path.append(out * radius + Vector((0, 0, 0.8 + 3.6 * t)))
            widths.append(1.05 - 0.75 * t)
        blade("Petal", path, widths, 0.2, side, pearl())
        # A light strip on the inside of each petal, and a lamp at its tip.
        inner = [p - out * 0.13 for p in path[2:-1]]
        blade("PetalLight", inner, [0.16] * len(inner), 0.06, side, light)
        ball("Tip", 0.2, path[-1] + Vector((0, 0, 0.12)), light)


cradle.egg_floor = 1.45
cradle.hover = 0.0
cradle.top = lambda scale, rarity: max(4.9, 1.45 + egg_height(scale, rarity) + 0.3)


def cradle_socket():
    lathe("Socket", [(0, 0), (1.9, 0), (2.0, 0.25), (1.6, 0.9), (1.35, 1.0), (0, 1.0)], pearl())
    # The petals closed into a bud: not bought yet.
    lathe("Bud", [(0, 0.9), (1.35, 0.9), (1.55, 1.6), (1.3, 2.5), (0.6, 3.2), (0, 3.4)], pearl(), 3)
    for angle in PETAL_ANGLES:
        out = Vector((math.sin(angle + math.pi / 3), -math.cos(angle + math.pi / 3), 0))
        rbox("Seam", (0.06, 0.06, 2.2), out * 1.2 + Vector((0, 0, 2.1)), steel_dark(), bevel=0.02,
             rotation=(0, 0, 0))
    ball("Tip", 0.14, (0, 0, 3.42), steel_dark())


# --- Direction C: one glass dome over the whole incubator, pedestals inside -----------------------


def pedestal(state, rarity, scale):
    light = glow(state_color(state), 5 if state == "ready" else 3.5)
    lathe("Pedestal", [(0, 0), (1.5, 0), (1.55, 0.25), (1.25, 0.8), (1.1, 0.9), (0, 0.9)], pearl())
    ring("Heater", 1.0, 0.09, (0, 0, 0.93), light)
    if state == "ready":
        # A ready egg's pedestal shines a beam up through the dome.
        cyl("Beam", 0.9, 5.6, (0, 0, 0.9 + 2.8), glass((0.6, 1.0, 0.65), 0.12), vertices=32)


pedestal.egg_floor = 0.95
pedestal.hover = 0.0
pedestal.top = lambda scale, rarity: 0.95 + egg_height(scale, rarity) + 0.3


def pedestal_socket():
    lathe("Pedestal", [(0, 0), (1.5, 0), (1.55, 0.25), (1.25, 0.8), (1.1, 0.9), (0, 0.9)], pearl())
    dome("Lid", 1.15, (0, 0, 0.9), steel(), squash=0.35)


def greenhouse_shell():
    radius, squash = DAIS_RADIUS - 0.2, 0.62
    dome("Dome", radius, (0, 0, DAIS_HEIGHT), glass((0.8, 0.9, 1.0), 0.12), squash=squash)
    ring("DomeFoot", radius, 0.2, (0, 0, DAIS_HEIGHT + 0.1), steel_light(), segments=128)
    # Ribs: vertical hoops, their lower halves inside the dais and the floor.
    for i in range(6):
        hoop = ring("Rib", radius, 0.12, (0, 0, DAIS_HEIGHT), steel_light(), rotation=(math.radians(90), 0, i * math.pi / 6), segments=96)
        hoop.scale = (1, 1, 1)
        hoop.matrix_world = Matrix.Translation((0, 0, DAIS_HEIGHT)) @ Matrix.Scale(squash, 4, (0, 0, 1)) @ Matrix.Rotation(
            i * math.pi / 6, 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X")
    ring("Crown", 1.6, 0.25, (0, 0, DAIS_HEIGHT + radius * squash), steel_light())
    ball("Lamp", 0.6, (0, 0, DAIS_HEIGHT + radius * squash + 0.3), glow(WARM, 4))


# --- Scene -------------------------------------------------------------------------------------

TITLES = {
    "bell": "А. Колба",
    "cradle": "Б. Бутон",
    "greenhouse": "В. Оранжерея",
}


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
        ("Fill", (22, -24, 8), 7000, (0.6, 0.7, 1.0), 18),
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
    objects = built(lambda: (
        rbox("LegL", (0.9, 0.9, 2.0), (-0.48, 0, 1.0), pants, 0.12),
        rbox("LegR", (0.9, 0.9, 2.0), (0.48, 0, 1.0), pants, 0.12),
        rbox("Torso", (2.0, 1.0, 2.0), (0, 0, 3.0), shirt, 0.15),
        rbox("ArmL", (0.9, 0.9, 2.0), (-1.48, 0, 3.0), skin, 0.12),
        rbox("ArmR", (0.9, 0.9, 2.0), (1.48, 0, 3.0), skin, 0.12),
        rbox("Head", (1.15, 1.15, 1.15), (0, 0, 4.6), skin, 0.3),
        rbox("Pack", (1.4, 0.7, 1.7), (0, -0.85, 3.1), steel_light(), 0.25),
    ))
    move(objects, Matrix.Translation((x, y, 0)) @ Matrix.Rotation(yaw, 4, "Z"))


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
    scene.render.filepath = os.path.join(OUT_DIR, f"incubator_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("Wrote", scene.render.filepath)


def build(direction):
    _cache.clear()
    _kit.clear()
    space()
    lights()
    cyl("Floor", 40, 1.0, (0, 0, -0.5), floor_mat(), vertices=96)
    capsule, socket = {
        "bell": (bell, bell_socket),
        "cradle": (cradle, cradle_socket),
        "greenhouse": (pedestal, pedestal_socket),
    }[direction]
    dais(core=direction != "greenhouse")
    fill(capsule, socket)
    if direction == "greenhouse":
        greenhouse_shell()
    labels(capsule)
    # The player walks in from the entrance.
    figure(-8.5, -16.5, math.radians(-25))
    text(TITLES[direction], (0, 8, 11.5), 1.3, glow((0.8, 0.85, 1.0), 1.4), rotation=(math.radians(75), 0, 0))


os.makedirs(OUT_DIR, exist_ok=True)
for direction in DIRECTIONS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build(direction)
    # The game's camera: behind and above the player walking in from the entrance.
    render(direction, (-8, -31, 13), (0, 0, 2.2), 30)
    # Close, at the first capsules: the three sizes and the ready egg.
    render(direction + "_near", (6, -20, 5.5), (0, -8.5, 2.6), 32, (1600, 1080))
