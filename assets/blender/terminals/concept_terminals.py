# Concept renders for the island terminals (docs/plans/POLISH.md, queue item 4;
# docs/design/screens/terminals.md): a few directions for the terminal's body, each shown in the
# three zones' colours (places blue, incubator orange, trainer yellow) beside a player-sized figure,
# with a mock of today's screen on it. A draft for review, not the final look.
#
# Studs = Blender units. The screen keeps its approved size and place: 6 x 4, its centre 5 above
# the floor (a player's head), tilted back 15 degrees. Blender +Z is up, the terminal faces -Y.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/terminals/concept_terminals.py -- <outdir> [direction ...]
# Directions: pillar, holo, bot.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))

import bpy  # noqa: E402
import real  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/terminals")
DIRECTIONS = ARGS[1:] or ["pillar", "holo", "bot"]

FONT_PATH = "C:/Windows/Fonts/seguibl.ttf"

SCREEN_W, SCREEN_H = 6.0, 4.0
SCREEN_CENTER = 5.0
SCREEN_TILT = math.radians(15)

# The zones' colours (BayLooks: PLACES_COLOR, INCUBATOR_COLOR, TRAINER_RING_COLOR), linear.
def srgb(r, g, b):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin(r), lin(g), lin(b))


ZONES = [
    # colour, title, value, hint, price
    (srgb(62, 166, 255), "Места", "12 / 30", "Пришелец на месте приносит монеты", "● 150"),
    (srgb(255, 170, 60), "Инкубатор", "5 / 6", "Есть свободное место", "● 2.4K"),
    (srgb(255, 214, 90), "Тренажёр", "Ур. 3", "+18 ⚡/с на стенде", "● 860"),
]
TEXT = srgb(234, 242, 255)
MUTED = srgb(157, 182, 210)
GOLD = srgb(255, 187, 46)


# The body's paint: a deep navy (first round), or the station's grey-blue steel (its concept,
# assets/blender/station/concept_station.py: hull, hull_light, hull_dark), linear.
NAVY = {"hull": srgb(52, 60, 104), "light": srgb(150, 160, 196), "trim": srgb(30, 36, 64)}
STEEL = {"hull": (0.30, 0.33, 0.42), "light": (0.72, 0.75, 0.82), "trim": (0.12, 0.13, 0.19)}
PALETTE = NAVY

# --- Materials ---------------------------------------------------------------------------------

_cache = {}


def mat(key, make):
    if key not in _cache:
        _cache[key] = make()
    return _cache[key]


def hull():
    """The body's paint: a deep navy with a satin coat, as the station's hulls."""
    return mat("hull", lambda: real.gloss("Hull", PALETTE["hull"], roughness=0.32, metallic=0.35))


def hull_light():
    """Lighter panels on the body (caps, shoulders)."""
    return mat("hullLight", lambda: real.gloss("HullLight", PALETTE["light"], roughness=0.28, metallic=0.4))


def trim():
    """Dark metal for bezels, joints and the base."""
    return mat("trim", lambda: real.chrome("Trim", PALETTE["trim"], roughness=0.3))


def glow(color, strength=4.0):
    return mat(("glow", color, strength), lambda: real.glow("Glow", color, strength * 0.7))


def screen_glass():
    """The screen's face: the dark blue of the UI canvas, slightly lit from within."""

    def make():
        m, nodes, links, bsdf = real._principled("Screen")
        grad = nodes.new("ShaderNodeTexGradient")
        coord = nodes.new("ShaderNodeTexCoord")
        mapping = nodes.new("ShaderNodeMapping")
        # Generated coordinates of the screen box: Z runs up the screen.
        mapping.inputs["Rotation"].default_value = (0, math.radians(-90), 0)
        links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], grad.inputs["Vector"])
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*srgb(10, 13, 44), 1)
        ramp.color_ramp.elements[1].color = (*srgb(22, 32, 96), 1)
        links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.2
        bsdf.inputs["Roughness"].default_value = 0.05
        bsdf.inputs["Coat Weight"].default_value = 1.0
        return m

    return mat("screen", make)


def holo_glass(color):
    """A see-through holographic pane: tinted glass with a faint glow."""

    def make():
        m, nodes, links, bsdf = real._principled("Holo")
        tint = tuple(0.15 + c * 0.25 for c in srgb(22, 32, 96))
        bsdf.inputs["Base Color"].default_value = (*tint, 1)
        bsdf.inputs["Transmission Weight"].default_value = 0.6
        bsdf.inputs["Roughness"].default_value = 0.05
        bsdf.inputs["Emission Color"].default_value = (*srgb(22, 32, 96), 1)
        bsdf.inputs["Emission Strength"].default_value = 1.6
        bsdf.inputs["Alpha"].default_value = 0.88
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        return m

    return mat(("holo", color), make)


def beam(color):
    """A soft light cone (a Beam/particles in game): bright at its axis, gone at its edge."""

    def make():
        m = bpy.data.materials.new("Beam")
        m.use_nodes = True
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        nodes, links = m.node_tree.nodes, m.node_tree.links
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")
        em = nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*color, 1)
        em.inputs["Strength"].default_value = 2.0
        facing = nodes.new("ShaderNodeLayerWeight")
        facing.inputs["Blend"].default_value = 0.4
        inv = nodes.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        links.new(facing.outputs["Facing"], inv.inputs[1])
        amount = nodes.new("ShaderNodeMath")
        amount.operation = "MULTIPLY"
        amount.inputs[1].default_value = 0.22
        links.new(inv.outputs[0], amount.inputs[0])
        clear = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        links.new(amount.outputs[0], mix.inputs["Fac"])
        links.new(clear.outputs[0], mix.inputs[1])
        links.new(em.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs[0])
        return m

    return mat(("beam", color), make)


def floor_mat():
    return mat("floor", lambda: real.gloss("Floor", srgb(40, 46, 70), roughness=0.85, metallic=0.1))


# --- Shapes ------------------------------------------------------------------------------------


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


def rbox(name, size, location, material, bevel=0.2, rotation=(0, 0, 0), parent=None, segments=4):
    """A box with rounded edges."""
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
        obj.modifiers.new("Normals", "WEIGHTED_NORMAL").keep_sharp = True
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj


def cyl(name, radius, depth, location, material, rotation=(0, 0, 0), vertices=48, radius2=None, parent=None, bevel=0.0):
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=radius2, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    obj.name = name
    smooth(obj)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj


def ball(name, radius, location, material, parent=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=32, ring_count=16)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    smooth(obj)
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj


def ring(name, major, minor, location, material, rotation=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=location, rotation=rotation, major_segments=72, minor_segments=12)
    obj = bpy.context.active_object
    obj.name = name
    smooth(obj)
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj


def local(obj, parent):
    """Puts `obj` (built at its local location) under `parent`: its location is in the parent's frame."""
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)


def empty(name, location=(0, 0, 0), rotation=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.location = location
    obj.rotation_euler = rotation
    bpy.context.scene.collection.objects.link(obj)
    if parent:
        local(obj, parent)
    return obj


def text(body, size, location, material, parent, align="CENTER", font=FONT_PATH):
    curve = bpy.data.curves.new("Text", "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = align
    curve.align_y = "CENTER"
    try:
        curve.font = bpy.data.fonts.load(font, check_existing=True)
    except RuntimeError:
        pass
    obj = bpy.data.objects.new("Text", curve)
    bpy.context.scene.collection.objects.link(obj)
    # Text lies in XY facing +Z; stand it up facing -Y (the screen's front).
    obj.rotation_euler = (math.radians(90), 0, 0)
    obj.location = location
    real.assign(obj, material)
    local(obj, parent)
    return obj


# --- The screen (today's approved layout) ------------------------------------------------------


def screen_ui(frame, color, title, value, hint, price, holo=False):
    """Today's screen on a 6 x 4 face centred on `frame` (an empty facing -Y): title in the zone's
    colour, a big number, a hint and the full-width gold price button."""
    face = -0.17 if not holo else -0.04
    title_col = tuple(c + (1 - c) * 0.2 for c in color)
    text(title, 0.56, (0, face, 1.32), flat(title_col, 1.6), frame)
    text(value, 0.92, (0, face, 0.45), flat(TEXT, 1.4), frame)
    # The hint, its ⚡ in the bolt's colour (the game draws an icon there).
    pieces = []
    for i, part in enumerate(hint.split("⚡")):
        if i > 0:
            pieces.append(("⚡", "C:/Windows/Fonts/seguisym.ttf", flat(srgb(255, 211, 74), 1.6)))
        if part:
            pieces.append((part, FONT_PATH, flat(MUTED, 1.2)))
    row(pieces, 0.33, (0, face, -0.35), frame)
    # The price button: a gold pill, full width (a box with round ends).
    gold = flat(tuple(c * 0.55 for c in GOLD), 1.0)
    height, width = 1.05, SCREEN_W - 0.8
    rbox("Button", (width - height, 0.04, height), (0, face + 0.02, -1.25), gold, 0, parent=frame)
    for side in (-1, 1):
        cyl("ButtonEnd", height / 2, 0.04, (side * (width - height) / 2, face + 0.02, -1.25), gold, rotation=(math.radians(90), 0, 0), parent=frame)
    text(price, 0.62, (0, face - 0.03, -1.27), flat(srgb(255, 240, 200), 1.8), frame)


def row(pieces, size, location, parent):
    """Text pieces in different fonts and colours side by side, centred on `location`."""
    objs = [text(body, size, (0, 0, 0), material, parent, "LEFT", font) for body, font, material in pieces]
    bpy.context.view_layer.update()
    gap = size * 0.12
    widths = [obj.dimensions.x for obj in objs]
    x = location[0] - (sum(widths) + gap * (len(objs) - 1)) / 2
    for obj, width in zip(objs, widths):
        obj.location = (x, location[1], location[2])
        x += width + gap


def flat(color, strength=1.0):
    """What the screen draws: pure light, no shading."""

    def make():
        m = bpy.data.materials.new("UI")
        m.use_nodes = True
        nodes, links = m.node_tree.nodes, m.node_tree.links
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")
        em = nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*color, 1)
        em.inputs["Strength"].default_value = strength
        links.new(em.outputs[0], out.inputs[0])
        return m

    return mat(("flat", color, strength), make)


# --- The player for scale ----------------------------------------------------------------------


def figure(x, y=0.0):
    """A blocky R15-sized player (about 5 studs) with a jetpack, facing the terminal."""
    skin = mat("skin", lambda: real.gloss("Skin", srgb(245, 205, 150), roughness=0.5))
    shirt = mat("shirt", lambda: real.gloss("Shirt", srgb(70, 110, 200), roughness=0.6))
    pants = mat("pants", lambda: real.gloss("Pants", srgb(40, 45, 60), roughness=0.6))
    root = empty("Player", (x, y, 0), (0, 0, math.radians(200)))
    rbox("LegL", (0.9, 0.9, 2.0), (-0.48, 0, 1.0), pants, 0.12, parent=root)
    rbox("LegR", (0.9, 0.9, 2.0), (0.48, 0, 1.0), pants, 0.12, parent=root)
    rbox("Torso", (2.0, 1.0, 2.0), (0, 0, 3.0), shirt, 0.15, parent=root)
    rbox("ArmL", (0.9, 0.9, 2.0), (-1.48, 0, 3.0), skin, 0.12, parent=root)
    rbox("ArmR", (0.9, 0.9, 2.0), (1.48, 0, 3.0), skin, 0.12, parent=root)
    rbox("Head", (1.15, 1.15, 1.15), (0, 0, 4.6), skin, 0.3, parent=root)
    rbox("Pack", (1.4, 0.7, 1.7), (0, 0.85, 3.1), hull_light(), 0.25, parent=root)
    return root


# --- Directions --------------------------------------------------------------------------------


def screen_frame(root, height=SCREEN_CENTER, tilt=SCREEN_TILT, y=0.0):
    """An empty at the screen's centre, tilted back (top away from the viewer), facing -Y."""
    return empty("ScreenFrame", (0, y, height), (-tilt, 0, 0), root)


def pillar(root, color, zone):
    """A: the kiosk. A sturdy tapered body on a round glowing foot (like an arcade cabinet, not a
    monitor on a stick), a lit stripe in the zone's colour down its front, a thick rounded bezel
    round the screen with a glowing lip, two side lights and a short antenna with a beacon."""
    # Foot: a low round plinth with a glowing ring.
    cyl("Foot", 1.9, 0.35, (0, 0, 0.175), trim(), parent=root, bevel=0.08)
    ring("FootGlow", 1.9, 0.07, (0, 0, 0.22), glow(color, 3), parent=root)
    # Body: a square tapered column, wide at the foot, rounded corners.
    cyl("Body", 1.25, 2.9, (0, 0.2, 1.8), hull(), radius2=0.8, vertices=4, rotation=(0, 0, math.radians(45)), parent=root, bevel=0.25)
    rbox("BodyPanel", (1.0, 0.1, 2.1), (0, -0.55, 1.7), hull_light(), 0.05, rotation=(math.radians(-8), 0, 0), parent=root)
    rbox("Stripe", (0.16, 0.12, 1.9), (0, -0.62, 1.7), glow(color, 3), 0.05, rotation=(math.radians(-8), 0, 0), parent=root)
    frame = screen_frame(root)
    # The head: a deep rounded bezel, a lighter back shell, the screen set into it.
    rbox("Bezel", (SCREEN_W + 0.7, 0.55, SCREEN_H + 0.7), (0, 0.18, 0), hull(), 0.32, parent=frame)
    rbox("Shell", (SCREEN_W - 0.4, 0.6, SCREEN_H - 0.4), (0, 0.6, -0.1), hull_light(), 0.4, parent=frame)
    rbox("Lip", (SCREEN_W + 0.32, 0.08, SCREEN_H + 0.32), (0, -0.08, 0), glow(color, 2.2), 0.2, parent=frame)
    rbox("Screen", (SCREEN_W, 0.12, SCREEN_H), (0, -0.1, 0), screen_glass(), 0.12, parent=frame)
    # Side lights and the antenna.
    for side in (-1, 1):
        ball("SideLight", 0.22, (side * (SCREEN_W / 2 + 0.38), 0.05, SCREEN_H / 2 - 0.5), glow(color, 6), parent=frame)
    cyl("Antenna", 0.06, 0.9, (SCREEN_W / 2 - 0.6, 0.35, SCREEN_H / 2 + 0.75), trim(), parent=frame)
    ball("Beacon", 0.17, (SCREEN_W / 2 - 0.6, 0.35, SCREEN_H / 2 + 1.25), glow(color, 7), parent=frame)
    screen_ui(frame, color, *zone)


def holo(root, color, zone):
    """B: the projector. A low rounded console on the floor (knee-high, the eye passes over it) with
    a glowing emitter ring on its sloped top; the screen is a pane of light hanging above it, held
    by nothing, framed by a thin glowing line, with a faint cone of light from the emitter. In game:
    a glass pane, a Beam and a few particles."""
    cyl("Foot", 1.9, 0.3, (0, 0, 0.15), trim(), parent=root, bevel=0.08)
    rbox("Console", (3.0, 2.2, 1.3), (0, 0.15, 0.9), hull(), 0.55, parent=root)
    rbox("ConsoleCap", (2.6, 1.8, 0.3), (0, 0.15, 1.55), hull_light(), 0.14, rotation=(math.radians(-12), 0, 0), parent=root)
    ring("Emitter", 0.7, 0.09, (0, 0.15, 1.75), glow(color, 6), rotation=(math.radians(-12), 0, 0), parent=root)
    cyl("Lens", 0.55, 0.12, (0, 0.15, 1.72), glow(tuple(c + (1 - c) * 0.6 for c in color), 5), rotation=(math.radians(-12), 0, 0), parent=root)
    rbox("FrontStripe", (2.2, 0.08, 0.14), (0, -0.96, 0.9), glow(color, 4), 0.05, parent=root)
    # The cone of light from the lens up to the pane's bottom edge.
    cyl("Beam", 0.5, 1.7, (0, 0.12, 2.6), beam(color), radius2=2.6, vertices=4, rotation=(0, 0, math.radians(45)), parent=root)
    frame = screen_frame(root)
    rbox("Pane", (SCREEN_W, 0.05, SCREEN_H), (0, 0, 0), holo_glass(color), 0.15, parent=frame)
    # A thin glowing frame line and corner ticks.
    for z in (-1, 1):
        rbox("Edge", (SCREEN_W + 0.1, 0.05, 0.06), (0, 0, z * (SCREEN_H / 2 + 0.03)), glow(color, 5), 0.02, parent=frame)
    for x in (-1, 1):
        rbox("Edge", (0.06, 0.05, SCREEN_H + 0.1), (x * (SCREEN_W / 2 + 0.03), 0, 0), glow(color, 5), 0.02, parent=frame)
        for z in (-1, 1):
            ball("Corner", 0.12, (x * (SCREEN_W / 2 + 0.03), 0, z * (SCREEN_H / 2 + 0.03)), glow(color, 7), parent=frame)
    screen_ui(frame, color, *zone, holo=True)


def bot(root, color, zone):
    """C: the helper bot, kin to the pets (robo hulls, visors, antennas). A round body on two stubby
    feet, the screen its big TV head with a rounded shell, ear lights and two antennas; a small arm
    points to the side its zone is on."""
    for side in (-1, 1):
        ball("Foot", 0.7, (side * 0.9, -0.2, 0.32), trim(), scale=(1, 1.4, 0.55), parent=root)
    ball("Body", 1.7, (0, 0.1, 1.95), hull(), scale=(1, 0.9, 1.0), parent=root)
    ball("Belly", 1.2, (0, -0.35, 1.85), hull_light(), scale=(1, 0.7, 1.0), parent=root)
    ring("Belt", 1.65, 0.09, (0, 0.1, 1.7), glow(color, 4), parent=root)
    # The arm: a shoulder ball, a short arm out to the side, a round hand.
    ball("Shoulder", 0.4, (1.65, 0.1, 2.2), hull_light(), parent=root)
    cyl("Arm", 0.17, 1.0, (2.1, 0.0, 2.5), trim(), rotation=(0, math.radians(50), 0), parent=root)
    ball("Hand", 0.3, (2.5, -0.05, 2.85), glow(color, 3), parent=root)
    frame = screen_frame(root, SCREEN_CENTER + 0.4, math.radians(8))
    # The TV head: a rounded shell round the screen, deeper than the pillar's bezel.
    rbox("Head", (SCREEN_W + 0.9, 1.1, SCREEN_H + 0.9), (0, 0.35, 0), hull(), 0.5, parent=frame, segments=6)
    rbox("Visor", (SCREEN_W + 0.3, 0.1, SCREEN_H + 0.3), (0, -0.23, 0), trim(), 0.35, parent=frame)
    rbox("Screen", (SCREEN_W, 0.12, SCREEN_H), (0, -0.26, 0), screen_glass(), 0.3, parent=frame)
    for side in (-1, 1):
        cyl("Ear", 0.45, 0.3, (side * (SCREEN_W / 2 + 0.55), 0.55, 0.2), hull_light(), rotation=(0, math.radians(90), 0), parent=frame)
        cyl("EarLight", 0.28, 0.1, (side * (SCREEN_W / 2 + 0.72), 0.55, 0.2), glow(color, 6), rotation=(0, math.radians(90), 0), parent=frame)
        cyl("Antenna", 0.05, 1.0, (side * 1.6, 0.6, SCREEN_H / 2 + 0.85), trim(), rotation=(0, side * math.radians(-15), 0), parent=frame)
        ball("Tip", 0.2, (side * 1.73, 0.6, SCREEN_H / 2 + 1.35), glow(color, 7), parent=frame)
    # The screen face sits further forward in the head.
    face = empty("Face", (0, -0.17, 0), parent=frame)
    screen_ui(face, color, *zone)


BUILDERS = {"pillar": pillar, "holo": holo, "bot": bot, "steel": holo}
TITLES = {
    "pillar": "А. Стойка-киоск",
    "holo": "Б. Голо-проектор",
    "bot": "В. Робот-помощник",
    "steel": "Б. Голо-проектор — сталь станции",
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
    noise.inputs["Detail"].default_value = 6.0
    l.new(coord.outputs["Generated"], noise.inputs["Vector"])
    ramp = n.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.45, (0.006, 0.007, 0.02, 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.8, (0.05, 0.03, 0.1, 1)
    l.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    stars = n.new("ShaderNodeTexVoronoi")
    stars.inputs["Scale"].default_value = 300.0
    l.new(coord.outputs["Generated"], stars.inputs["Vector"])
    dot = n.new("ShaderNodeMath")
    dot.operation = "LESS_THAN"
    dot.inputs[1].default_value = 0.035
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
    """The sun from the upper left (SkyLooks: ClockTime 10), a cool fill and a violet rim."""
    scene = bpy.context.scene
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(3)
    sun.color = (1.0, 0.95, 0.88)
    obj = bpy.data.objects.new("Sun", sun)
    obj.rotation_euler = (math.radians(50), math.radians(-25), math.radians(-35))
    scene.collection.objects.link(obj)
    target = Vector((0, 0, 3))
    for name, location, energy, colour, size in (
        ("Fill", (22, -20, 6), 5000, (0.6, 0.7, 1.0), 18),
        ("Rim", (-6, 24, 14), 9000, (0.75, 0.6, 1.0), 20),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, colour
        # No highlights of the big soft lights on the floor (they read as white patches).
        data.specular_factor = 0.0
        light = bpy.data.objects.new(name, data)
        light.location = location
        light.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)


def island_floor():
    """A slab of the island's floor and the zones' lines on it."""
    cyl("Floor", 34, 1.0, (0, 6, -0.5), floor_mat(), vertices=96)


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
    obj.rotation_euler = (math.radians(90), 0, 0)
    obj.location = location
    real.assign(obj, glow((0.8, 0.85, 1.0), 1.4))


def render(name, camera_at, look_at, lens=32, size=(1920, 1080)):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
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
    scene.render.filepath = os.path.join(OUT_DIR, f"terminal_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("Wrote", scene.render.filepath)


def build(direction):
    _cache.clear()
    space()
    lights()
    island_floor()
    for i, zone in enumerate(ZONES):
        x = (i - 1) * 11
        # Turned a little toward the camera on the sides, as they stand round the entrance.
        root = empty("Terminal", (x, 0, 0), (0, 0, math.radians(-i * 6 + 6)))
        BUILDERS[direction](root, zone[0], zone[1:])
    # The player stands at the incubator's terminal, a step in front and to the side.
    figure(-3.6, -3.6)
    label(TITLES[direction], Vector((0, 3, 10.6)), 1.0)


for direction in DIRECTIONS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PALETTE = STEEL if direction == "steel" else NAVY
    build(direction)
    render(direction, (7, -27, 8.5), (0, 0, 3.6), 30)
    # A close look at the incubator's one from its side: the body's depth and the screen's tilt.
    render(direction + "_side", (10, -11, 6.5), (0.3, 0, 3.4), 35, (960, 1080))
    if direction == "steel":
        # From behind, as a player walking past it sees it: the pane's back is dim glass, no text.
        render(direction + "_back", (-9, 14, 6.5), (0, 0, 3.4), 35, (960, 1080))
