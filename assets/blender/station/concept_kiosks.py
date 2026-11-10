# Concept renders for the station's kiosks (user, 2026-11-10: "more futuristic-cartoony, fitting
# the overall style"): the four stalls of the market street under the ring (jetpacks, shop, quests,
# gift), in the look of the robot pets (smooth pearl shells, glass caps, visors with glowing eyes,
# decision 074) and the holo terminals (dark navy pills with a glowing strip). Three directions,
# one picture each, with a player for scale. A draft for review, not the final look.
#
#   pod   - an upright capsule cut open at the front, a round glowing badge floating above;
#   bot   - a round counter with a robot shopkeeper behind it, a pill canopy;
#   cart  - a hover cart with the goods in a glass bubble, a pill sign at its back.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/station/concept_kiosks.py -- <outdir> [direction ...] [--fast]

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import real  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FAST = "--fast" in ARGS
POSITIONAL = [a for a in ARGS if not a.startswith("--")]
OUT_DIR = os.path.abspath(POSITIONAL[0] if POSITIONAL else "out/station")
DIRECTIONS = POSITIONAL[1:] or ["pod", "bot", "cart"]

FONT_PATH = "C:/Windows/Fonts/seguibl.ttf"

# The four stalls: their sign, accent colour and icon.
STALLS = [
    ("ДЖЕТПАКИ", (1.0, 0.45, 0.12), "jetpack"),
    ("МАГАЗИН", (0.6, 0.38, 1.0), "gem"),
    ("ЗАДАНИЯ", (0.15, 0.9, 0.7), "quest"),
    ("ПОДАРОК", (1.0, 0.32, 0.68), "gift"),
]
SPACING = 17.0
WHITE = (0.95, 0.97, 1.0)
GOLDEN = (1.0, 0.85, 0.45)

# --- Materials ---------------------------------------------------------------------------------

_cache = {}


def cached(key, make):
    if key not in _cache:
        _cache[key] = make()
    return _cache[key]


def pearl():
    return cached("pearl", lambda: real.gloss("Pearl", (0.84, 0.86, 0.92), 0.18))


def navy():
    return cached("navy", lambda: real.gloss("Navy", (0.035, 0.05, 0.12), 0.25))


def black():
    return cached("black", lambda: real.gloss("Visor", (0.01, 0.012, 0.02), 0.05))


def glass():
    def make():
        m, nodes, links, bsdf = real._principled("Glass")
        bsdf.inputs["Base Color"].default_value = (0.85, 0.95, 1.0, 1)
        bsdf.inputs["Roughness"].default_value = 0.03
        bsdf.inputs["Transmission Weight"].default_value = 1.0
        bsdf.inputs["IOR"].default_value = 1.2
        bsdf.inputs["Coat Weight"].default_value = 1.0
        return m
    return cached("glass", make)


def paint(colour):
    return cached(("paint", colour), lambda: real.gloss("Paint", colour, 0.22))


def glow(colour, strength=4.0):
    return cached(("glow", colour, strength), lambda: real.glow("Glow", colour, strength))


def holo(colour):
    """A hologram: see-through and glowing."""
    def make():
        m = bpy.data.materials.new("Holo")
        m.use_nodes = True
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        n, l = m.node_tree.nodes, m.node_tree.links
        n.clear()
        out = n.new("ShaderNodeOutputMaterial")
        em = n.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*colour, 1)
        em.inputs["Strength"].default_value = 3.0
        tr = n.new("ShaderNodeBsdfTransparent")
        mix = n.new("ShaderNodeMixShader")
        mix.inputs["Fac"].default_value = 0.6
        l.new(tr.outputs[0], mix.inputs[1])
        l.new(em.outputs[0], mix.inputs[2])
        l.new(mix.outputs[0], out.inputs[0])
        return m
    return cached(("holo", colour), make)


def bubble(colour):
    """A glass bubble that reads against black space: clear in the middle, a bright rim and a
    faint tint of the stall's colour (plain glass mirrors the dark sky and turns black)."""
    def make():
        m = bpy.data.materials.new("Bubble")
        m.use_nodes = True
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        n, l = m.node_tree.nodes, m.node_tree.links
        n.clear()
        out = n.new("ShaderNodeOutputMaterial")
        em = n.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*[0.5 + c * 0.5 for c in colour], 1)
        em.inputs["Strength"].default_value = 2.0
        facing = n.new("ShaderNodeLayerWeight")
        facing.inputs["Blend"].default_value = 0.4
        edge = n.new("ShaderNodeMath")
        edge.operation = "POWER"
        edge.inputs[1].default_value = 2.0
        l.new(facing.outputs["Facing"], edge.inputs[0])
        amount = n.new("ShaderNodeMath")
        amount.operation = "MULTIPLY_ADD"
        amount.inputs[1].default_value = 0.8
        amount.inputs[2].default_value = 0.08
        l.new(edge.outputs[0], amount.inputs[0])
        tr = n.new("ShaderNodeBsdfTransparent")
        gloss = n.new("ShaderNodeBsdfGlossy")
        gloss.inputs["Roughness"].default_value = 0.05
        shine = n.new("ShaderNodeAddShader")
        l.new(em.outputs[0], shine.inputs[0])
        l.new(gloss.outputs[0], shine.inputs[1])
        mix = n.new("ShaderNodeMixShader")
        l.new(amount.outputs[0], mix.inputs["Fac"])
        l.new(tr.outputs[0], mix.inputs[1])
        l.new(shine.outputs[0], mix.inputs[2])
        l.new(mix.outputs[0], out.inputs[0])
        return m
    return cached(("bubble", colour), make)


def floor_mat():
    def make():
        m, nodes, links, bsdf = real._principled("Floor")
        coord = nodes.new("ShaderNodeTexCoord")
        brick = nodes.new("ShaderNodeTexBrick")
        brick.inputs["Scale"].default_value = 0.12
        brick.inputs["Mortar Size"].default_value = 0.02
        brick.inputs["Color1"].default_value = (0.2, 0.22, 0.29, 1)
        brick.inputs["Color2"].default_value = (0.16, 0.18, 0.25, 1)
        brick.inputs["Mortar"].default_value = (0.1, 0.11, 0.16, 1)
        links.new(coord.outputs["Object"], brick.inputs["Vector"])
        links.new(brick.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.6
        return m
    return cached("floor", make)


# --- Shapes ------------------------------------------------------------------------------------


def active():
    return bpy.context.active_object


def smooth(obj, angle=None):
    if angle is None:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    else:
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    return obj


def rounded_box(at, size, mat, radius=0.6):
    """A soft box: every edge rounded, like a toy."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = active()
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    bevel = obj.modifiers.new("Round", "BEVEL")
    bevel.width = min(radius, min(size) / 2 - 0.01)
    bevel.segments = 6
    bevel.limit_method = "NONE"
    smooth(obj, 40)
    real.assign(obj, mat)
    return obj


def pill(at, length, radius, mat, axis="Z"):
    """A capsule along `axis`: a cylinder with round ends."""
    rot = {"X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0), "Z": (0, 0, 0)}[axis]
    d = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}[axis]
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=length, location=at, rotation=rot, vertices=48)
    parts = [active()]
    for s in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=Vector(at) + d * s * length / 2, segments=48, ring_count=24)
        parts.append(active())
    for p in parts:
        smooth(p)
        real.assign(p, mat)
    return parts


def ball(at, radius, mat, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=at, segments=48, ring_count=24)
    obj = active()
    obj.scale = scale
    smooth(obj)
    real.assign(obj, mat)
    return obj


def cylinder(at, radius, depth, mat, radius2=None, rotation=(0, 0, 0), vertices=64):
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=at, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=radius2, depth=depth, location=at, rotation=rotation, vertices=vertices)
    obj = active()
    smooth(obj, 35)
    real.assign(obj, mat)
    return obj


def torus(at, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=at, rotation=rotation, major_segments=72, minor_segments=16)
    obj = active()
    smooth(obj)
    real.assign(obj, mat)
    return obj


def text(body, at, size, mat):
    """Upright text facing -Y (the camera)."""
    bpy.ops.object.text_add(location=at, rotation=(math.radians(90), 0, 0))
    obj = active()
    obj.data.body = body
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.size = size
    obj.data.extrude = 0.04
    try:
        obj.data.font = bpy.data.fonts.load(FONT_PATH, check_existing=True)
    except RuntimeError:
        pass
    real.assign(obj, mat)
    return obj


def join(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return active()


def boolean_cut(target, cutter):
    mod = target.modifiers.new("Cut", "BOOLEAN")
    mod.object = cutter
    mod.operation = "DIFFERENCE"
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier="Cut")
    bpy.data.objects.remove(cutter)


def cap(at, radius, mat):
    """The top half of a sphere: a glass bubble."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=at, segments=64, ring_count=32)
    obj = active()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    bm.to_mesh(obj.data)
    bm.free()
    smooth(obj)
    real.assign(obj, mat)
    return obj


# --- Icons: what each stall sells, as a little 3D sign ------------------------------------------


def icon(kind, at, s, colour):
    at = Vector(at)
    mat = glow(colour, 3.0)
    if kind == "jetpack":
        # Two tanks either side of a slim back plate, each with a nozzle and a flame under it.
        rounded_box(at + Vector((0, 0.25 * s, 0.35 * s)), (0.7 * s, 0.4 * s, 1.9 * s), navy(), 0.15 * s)
        for side in (-1, 1):
            tank = at + Vector((side * 0.85 * s, 0, 0.45 * s))
            pill(tank, 1.3 * s, 0.5 * s, mat)
            cylinder(tank - Vector((0, 0, 1.25 * s)), 0.32 * s, 0.35 * s, navy(), radius2=0.42 * s, vertices=24)
            cylinder(tank - Vector((0, 0, 2.0 * s)), 0.38 * s, 1.1 * s, glow(GOLDEN, 5.0), radius2=0.0, rotation=(math.pi, 0, 0), vertices=24)
    elif kind == "gem":
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.4 * s, radius2=0, depth=1.7 * s, location=at - Vector((0, 0, 0.6 * s)), rotation=(math.pi, 0, 0))
        real.assign(active(), mat)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.4 * s, radius2=0.8 * s, depth=0.7 * s, location=at + Vector((0, 0, 0.6 * s)))
        real.assign(active(), mat)
    elif kind == "quest":
        rounded_box(at, (2.0 * s, 0.3 * s, 2.5 * s), mat, 0.25 * s)
        rounded_box(at + Vector((0, 0, 1.3 * s)), (0.9 * s, 0.4 * s, 0.4 * s), navy(), 0.15 * s)
        for i in range(3):
            z = at.z + (0.6 - i * 0.6) * s
            rounded_box(Vector((at.x + 0.25 * s, at.y - 0.2 * s, z)), (1.0 * s, 0.1 * s, 0.22 * s), navy(), 0.08 * s)
            ball(Vector((at.x - 0.6 * s, at.y - 0.2 * s, z)), 0.16 * s, navy())
    elif kind == "gift":
        rounded_box(at, (2.0 * s, 2.0 * s, 1.7 * s), mat, 0.2 * s)
        rounded_box(at, (0.4 * s, 2.06 * s, 1.76 * s), glow(GOLDEN, 3.0), 0.1 * s)
        rounded_box(at, (2.06 * s, 0.4 * s, 1.76 * s), glow(GOLDEN, 3.0), 0.1 * s)
        for side in (-1, 1):
            torus(at + Vector((side * 0.45 * s, 0, 1.15 * s)), 0.42 * s, 0.13 * s, glow(GOLDEN, 3.0), rotation=(math.pi / 2, side * 0.5, 0))


def badge(at, label, colour, kind, size=1.0):
    """A round glowing badge with the stall's icon, its name on a pill under it."""
    at = Vector(at)
    torus(at, 2.6 * size, 0.28 * size, glow(colour, 4.0), rotation=(math.pi / 2, 0, 0))
    cylinder(at + Vector((0, 0.15, 0)), 2.5 * size, 0.2 * size, navy(), rotation=(math.pi / 2, 0, 0))
    icon(kind, at - Vector((0, 0.6 * size, 0)), 0.85 * size, colour)
    plate = at - Vector((0, 0, 3.6 * size))
    width = len(label) * 0.95 * size + 1.4
    rounded_box(plate, (width, 0.5, 1.7 * size), navy(), 0.8 * size)
    rounded_box(plate + Vector((0, 0.1, 0)), (width + 0.4, 0.4, 2.0 * size), glow(colour, 2.5), 0.95 * size)
    text(label, plate - Vector((0, 0.3, 0.05)), 1.15 * size, glow(WHITE, 2.5))


def hover_base(base, radius, colour):
    cylinder(base + Vector((0, 0, 0.35)), radius, 0.7, navy())
    torus(base + Vector((0, 0, 0.1)), radius, 0.18, glow(colour, 4.0))


# --- Directions --------------------------------------------------------------------------------


def pod(x, label, colour, kind):
    """An upright capsule cut open at the front: pearl shell, navy inside, a counter in its mouth."""
    base = Vector((x, 0, 0))
    hover_base(base, 5.2, colour)
    shell_c = base + Vector((0, 0, 6.2))
    shell = ball(shell_c, 4.4, pearl(), (1, 1, 1.5))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = shell
    shell.select_set(True)
    bpy.ops.object.transform_apply(scale=True)
    cut = rounded_box(base + Vector((0, -3.4, 5.6)), (6.4, 6.0, 7.4), pearl(), 1.4)
    boolean_cut(shell, cut)
    # The inside, dark like a terminal, with a glowing back panel and the goods.
    ball(shell_c + Vector((0, 0.6, 0)), 4.05, navy(), (1, 0.62, 1.45))
    rounded_box(base + Vector((0, -1.9, 6.6)), (4.0, 0.2, 3.6), holo(colour), 0.5)
    icon(kind, base + Vector((0, -2.7, 6.4)), 1.0, colour)
    # An accent band round the shell; the counter in front, a glowing strip on it.
    torus(base + Vector((0, 0, 1.6)), 4.45, 0.35, paint(colour))
    rounded_box(base + Vector((0, -3.2, 1.9)), (6.6, 2.0, 2.6), pearl(), 0.9)
    rounded_box(base + Vector((0, -4.22, 2.2)), (5.6, 0.1, 0.35), glow(colour, 4.0), 0.04)
    # Two antennae with glowing tips, like the worm pet's.
    top = shell_c.z + 4.4 * 1.5 - 0.3
    for side in (-1, 1):
        cylinder(base + Vector((side * 1.3, 0, top + 0.6)), 0.12, 1.8, pearl(), rotation=(0, side * 0.3, 0), vertices=12)
        ball(base + Vector((side * 1.57, 0, top + 1.45)), 0.38, glow(colour, 4.0))
    badge(base + Vector((0, -0.5, top + 6.2)), label, colour, kind)


def bot(x, label, colour, kind):
    """A round counter with a robot shopkeeper behind it and a pill canopy over both."""
    base = Vector((x, 0, 0))
    hover_base(base, 5.6, colour)
    # The counter: a pearl ring open at the back, a stripe in the accent colour.
    counter = cylinder(base + Vector((0, 0, 1.9)), 4.6, 2.6, pearl())
    hole = cylinder(base + Vector((0, 1.6, 1.9)), 3.6, 3.0, pearl())
    boolean_cut(counter, hole)
    bevel = counter.modifiers.new("Round", "BEVEL")
    bevel.width, bevel.segments = 0.35, 4
    torus(base + Vector((0, 0, 3.2)), 4.6, 0.3, paint(colour))
    # The shopkeeper: a pet-like robot with a visor and two glowing eyes, waving.
    body = base + Vector((0, 1.8, 4.3))
    ball(body, 1.9, pearl(), (1, 1, 1.1))
    torus(body + Vector((0, 0, -0.9)), 1.75, 0.2, paint(colour))
    head = body + Vector((0, 0, 3.0))
    ball(head, 1.7, pearl())
    rounded_box(head + Vector((0, -1.3, 0.1)), (2.4, 0.8, 1.0), black(), 0.45)
    for side in (-1, 1):
        ball(head + Vector((side * 0.5, -1.72, 0.15)), 0.22, glow((0.85, 0.97, 1.0), 6.0), (1, 0.5, 1))
        ball(body + Vector((side * 2.2, -0.6, -0.2 + (1.4 if side > 0 else 0))), 0.6, pearl())
    cylinder(head + Vector((0, 0, 2.0)), 0.1, 1.0, pearl(), vertices=12)
    ball(head + Vector((0, 0, 2.6)), 0.3, glow(colour, 4.0))
    # The canopy: two pill posts and a long soft roof in the accent colour.
    for side in (-1, 1):
        pill(base + Vector((side * 4.6, 2.6, 5.0)), 8.0, 0.35, pearl())
    rounded_box(base + Vector((0, 0.4, 9.6)), (12.0, 7.0, 1.0), paint(colour), 0.5)
    rounded_box(base + Vector((0, -3.12, 9.6)), (11.0, 0.1, 0.3), glow(WHITE, 3.0), 0.04)
    # The goods on display, small, on the counter.
    icon(kind, base + Vector((-2.6, -2.2, 4.4)), 0.55, colour)
    badge(base + Vector((0, 0.6, 15.0)), label, colour, kind)


def cart(x, label, colour, kind):
    """A hover cart: a soft pearl body on a glowing hover skirt, the goods floating in a glass
    bubble, a tall pill sign at its back."""
    base = Vector((x, 0, 0))
    for side in (-1, 1):
        cylinder(base + Vector((side * 3.0, 0, 0.5)), 1.3, 0.3, glow(colour, 5.0))
    rounded_box(base + Vector((0, 0, 1.6)), (9.0, 5.0, 1.4), navy(), 0.6)
    rounded_box(base + Vector((0, 0, 3.6)), (9.4, 5.4, 3.0), pearl(), 1.2)
    rounded_box(base + Vector((0, -2.74, 3.8)), (7.6, 0.1, 0.4), glow(colour, 4.0), 0.04)
    rounded_box(base + Vector((0, -2.72, 2.7)), (8.4, 0.12, 0.6), paint(colour), 0.05)
    # The glass bubble on a ring, the goods floating inside.
    cylinder(base + Vector((0, -0.3, 5.3)), 3.0, 0.5, paint(colour))
    torus(base + Vector((0, -0.3, 5.55)), 3.0, 0.18, glow(colour, 4.0))
    cap(base + Vector((0, -0.3, 5.55)), 3.0, bubble(colour))
    icon(kind, base + Vector((0, -0.3, 7.4)), 0.9, colour)
    cylinder(base + Vector((0, -0.3, 5.9)), 1.2, 0.2, holo(colour))
    # The sign: a tall pill at the back holding up the badge.
    pill(base + Vector((0, 2.2, 8.0)), 6.0, 0.4, pearl())
    badge(base + Vector((0, 1.8, 14.5)), label, colour, kind)


BUILDERS = {"pod": pod, "bot": bot, "cart": cart}

# --- Scene ---------------------------------------------------------------------------------------


def roblox_player(at):
    """A blocky Roblox avatar for scale, about 5 studs tall."""
    at = Vector(at)
    skin = cached("skin", lambda: real.gloss("Skin", (0.85, 0.68, 0.45), 0.5))
    shirt = cached("shirt", lambda: real.gloss("Shirt", (0.1, 0.3, 0.75), 0.5))
    pants = cached("pants", lambda: real.gloss("Pants", (0.05, 0.06, 0.1), 0.5))
    for side in (-1, 1):
        rounded_box(at + Vector((side * 0.5, 0, 1.0)), (0.95, 0.95, 2.0), pants, 0.1)
        rounded_box(at + Vector((side * 1.5, 0, 3.0)), (0.95, 0.95, 2.0), skin, 0.1)
    rounded_box(at + Vector((0, 0, 3.0)), (2.0, 1.0, 2.0), shirt, 0.1)
    rounded_box(at + Vector((0, 0, 4.6)), (1.2, 1.2, 1.2), skin, 0.2)
    rounded_box(at + Vector((0, 0.75, 3.1)), (1.4, 0.6, 1.6), cached("pack", lambda: real.gloss("Pack", (0.4, 0.44, 0.55), 0.3, 0.6)), 0.2)


def space():
    w = bpy.data.worlds.new("Space")
    bpy.context.scene.world = w
    w.use_nodes = True
    n, l = w.node_tree.nodes, w.node_tree.links
    bg = n.get("Background")
    coord = n.new("ShaderNodeTexCoord")
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
    add.inputs[6].default_value = (0.012, 0.012, 0.035, 1)
    l.new(dot.outputs[0], add.inputs[7])
    l.new(add.outputs[2], bg.inputs["Color"])


def lights():
    scene = bpy.context.scene
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy, sun.color, sun.angle = 2.6, (1.0, 0.93, 0.84), math.radians(3)
    obj = bpy.data.objects.new("Sun", sun)
    obj.rotation_euler = Vector((0.45, 0.6, -0.65)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(obj)
    for name, loc, energy, colour in (("Fill", (-30, -40, 18), 30000, (0.6, 0.6, 1.0)), ("Rim", (20, 30, 25), 40000, (0.5, 0.8, 1.0))):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, 30, colour
        o = bpy.data.objects.new(name, data)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 4)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(o)


def render(name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", not FAST), ("taa_render_samples", 16 if FAST else 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = (960, 540) if FAST else (1920, 1080)
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.3
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 24
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (-4, -42, 11)
    cam.rotation_euler = (Vector((0, 0, 8.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT_DIR, f"kiosks_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("Wrote", scene.render.filepath)


if __name__ == "__main__":
    for direction in DIRECTIONS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _cache.clear()
        space()
        lights()
        bpy.ops.mesh.primitive_cylinder_add(radius=80, depth=1, location=(0, 0, -0.5), vertices=96)
        real.assign(active(), floor_mat())
        for i, (label, colour, kind) in enumerate(STALLS):
            BUILDERS[direction]((i - 1.5) * SPACING, label, colour, kind)
        roblox_player((-0.5 * SPACING + 0.3, -9.5, 0))
        render(direction)
