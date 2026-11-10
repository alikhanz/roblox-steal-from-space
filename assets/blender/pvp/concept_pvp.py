# Concept renders for the PvP abilities' look (docs/plans/POLISH.md, "PvP": rework the magnetic
# harpoon and the gravity bomb). Three concepts each, every concept as three phases seen from the
# game's camera (behind and above the shooter). Storyboards, not models: the shapes only show what
# would fly, light and move; the game would draw it with a few MeshParts and Beams.
#
# Studs = Blender units. The shooter floats at the origin facing -Y (as the pets and the trainer's
# rider), the camera behind it at +Y. Colours: the HUD buttons' (DESIGN.md) — harpoon #3FD9FF,
# bomb #B57BFF — and the station's steel and pearl (concept_stand.py).
#
# Run headless from the repo root (PowerShell):
#   & "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python assets/blender/pvp/concept_pvp.py -- <outdir> [concept ...]
# Concepts: h1 h2 h3 b1 b2 b3 (all by default). Writes <outdir>/<concept>_<phase>.png.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "jetpacks"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import jetpacks  # noqa: E402
import real  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/pvp")
CONCEPTS = [a for a in ARGS[1:]] or ["h1", "h2", "h3", "b1", "b2", "b3"]


def srgb(r, g, b):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin(r), lin(g), lin(b))


CYAN = srgb(63, 217, 255)  # Theme.FLIGHT.Harpoon
VIOLET = srgb(181, 123, 255)  # Theme.FLIGHT.Bomb
DEEP_VIOLET = srgb(85, 70, 255)  # reads violet on the islands (BLENDER_ROBLOX.md §2)
WHITE = (1.0, 1.0, 1.0)
STEEL = (0.30, 0.33, 0.42)
STEEL_DARK = (0.12, 0.13, 0.19)
PEARL = (0.84, 0.86, 0.92)
NAVY = (0.035, 0.05, 0.12)
GOLD_EGG = srgb(255, 200, 60)  # EggLooks Legendary
GREEN_EGG = srgb(120, 235, 130)  # EggLooks Uncommon

# --- Materials ---------------------------------------------------------------------------------

_cache = {}


def mat(key, make):
    if key not in _cache:
        _cache[key] = make()
    return _cache[key]


def pearl():
    return mat("pearl", lambda: real.gloss("Pearl", PEARL, roughness=0.18))


def steel():
    return mat("steel", lambda: real.gloss("Steel", STEEL, roughness=0.32, metallic=0.35))


def dark():
    return mat("dark", lambda: real.chrome("Dark", STEEL_DARK, roughness=0.3))


def navy():
    return mat("navy", lambda: real.gloss("Navy", NAVY, roughness=0.2))


def void():
    def make():
        m = real.gloss("Void", (0.0, 0.0, 0.0), roughness=1.0)
        m.node_tree.nodes.get("Principled BSDF").inputs["Coat Weight"].default_value = 0.0
        return m

    return mat("void", make)


def glow(color, strength=4.0):
    return mat(("glow", color, strength), lambda: real.glow("Glow", color, strength))


def _soft(name, color, strength, alpha, mode):
    """Transparent light. mode "core": bright along the axis, fading to the edge (a beam, a jet);
    "rim": bright at the edge (a shell seen through); "flat": even (a disc, a ribbon)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    nodes, links = m.node_tree.nodes, m.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = strength
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    scale = nodes.new("ShaderNodeMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = alpha
    if mode == "flat":
        scale.inputs[0].default_value = 1.0
    else:
        facing = nodes.new("ShaderNodeLayerWeight")
        facing.inputs["Blend"].default_value = 0.5
        power = nodes.new("ShaderNodeMath")
        power.operation = "POWER"
        power.inputs[1].default_value = 2.5 if mode == "rim" else 1.5
        if mode == "core":
            inv = nodes.new("ShaderNodeMath")
            inv.operation = "SUBTRACT"
            inv.inputs[0].default_value = 1.0
            links.new(facing.outputs["Facing"], inv.inputs[1])
            links.new(inv.outputs[0], power.inputs[0])
        else:
            links.new(facing.outputs["Facing"], power.inputs[0])
        links.new(power.outputs[0], scale.inputs[0])
    links.new(scale.outputs[0], mix.inputs["Fac"])
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(em.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs[0])
    return m


def soft(color, strength=5.0, alpha=1.0, mode="core"):
    return mat(("soft", color, strength, alpha, mode), lambda: _soft("Soft", color, strength, alpha, mode))


# --- Shapes ------------------------------------------------------------------------------------


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


def local(obj, parent):
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)


def empty(name, location=(0, 0, 0), rotation=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    obj.location = location
    obj.rotation_euler = rotation
    bpy.context.scene.collection.objects.link(obj)
    return obj


def rbox(size, location, material, bevel=0.15, rotation=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = min(bevel, min(size) * 0.49)
        mod.segments = 4
        mod.limit_method = "NONE"
        smooth(obj)
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj


def ball(radius, location, material, scale=(1, 1, 1), parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=40, ring_count=20)
    obj = bpy.context.active_object
    obj.scale = scale
    smooth(obj)
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj


def capsule(radius, height, location, material, rotation=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=(0, 0, 0), segments=32, ring_count=16)
    obj = bpy.context.active_object
    half = max(0.0, height / 2 - radius)
    for v in obj.data.vertices:
        v.co.z += half if v.co.z > 0 else -half if v.co.z < 0 else 0
    obj.location = location
    obj.rotation_euler = rotation
    smooth(obj)
    real.assign(obj, material)
    if parent:
        local(obj, parent)
    return obj


def torus(major, minor, location, material, rotation=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        location=location,
        rotation=rotation,
        major_segments=96,
        minor_segments=12,
    )
    obj = bpy.context.active_object
    obj.scale = scale
    smooth(obj)
    real.assign(obj, material)
    return obj


def tube(a, b, radius, material, radius2=None, vertices=24):
    """A cylinder (or a cone, `radius` at `a`, `radius2` at `b`) from `a` to `b`."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rotation = d.to_track_quat("Z", "Y").to_euler()
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=d.length, location=(a + b) / 2, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(
            radius1=radius, radius2=radius2, depth=d.length, location=(a + b) / 2, rotation=rotation, vertices=vertices
        )
    obj = bpy.context.active_object
    smooth(obj)
    real.assign(obj, material)
    return obj


def zigzag(a, b, segments, amplitude, radius, material, seed):
    """A lightning arc from `a` to `b`: a broken line of thin tubes."""
    a, b = Vector(a), Vector(b)
    d = b - a
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    points = [a]
    for i in range(1, segments):
        t = i / segments
        s = math.sin(seed * 12.9898 + i * 78.233) * 43758.5453
        r1 = (s - math.floor(s)) * 2 - 1
        s2 = math.sin(seed * 4.1 + i * 19.19) * 9631.77
        r2 = (s2 - math.floor(s2)) * 2 - 1
        points.append(a + d * t + side * r1 * amplitude + up * r2 * amplitude * 0.6)
    points.append(b)
    for p, q in zip(points, points[1:]):
        tube(p, q, radius, material, vertices=8)
        ball(radius, q, material)


def rock(location, radius, seed):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, location=location, subdivisions=4)
    obj = bpy.context.active_object
    obj.rotation_euler = (seed, seed * 2.1, seed * 0.7)
    tex = bpy.data.textures.new("Rock", "CLOUDS")
    tex.noise_scale = 0.6
    mod = obj.modifiers.new("Displace", "DISPLACE")
    mod.texture = tex
    mod.strength = radius * 0.35
    smooth(obj)
    real.assign(obj, mat("rock", lambda: real.gloss("Rock", srgb(70, 64, 80), roughness=0.9)))
    return obj


# --- Characters --------------------------------------------------------------------------------


def egg(location, color, rotation=(0, 0, 0)):
    """A medium egg capsule (decision 088): pearl below, the rarity's colour above, a lit seam."""
    root = empty("Egg", location, rotation)
    capsule(0.8, 2.1, (0, 0, 0), pearl(), parent=root)
    top = ball(0.82, (0, 0, 0.32), mat(("eggTop", color), lambda: real.gloss("EggTop", color, 0.2)), parent=root)
    top.scale = (1, 1, 0.92)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.8, minor_radius=0.06, location=(0, 0, 0.3))
    seam = bpy.context.active_object
    real.assign(seam, glow(color, 4))
    local(seam, root)
    return root


def figure(feet, yaw=0.0, pose="idle", shirt=(70, 110, 200), tilt=0.0, jetpack=True, flame=1.0):
    """A blocky R15 player floating with its feet at `feet`, facing -Y turned by `yaw`.
    Poses: "aim" (right arm straight at -Y), "throw" (right arm up-forward), "carry" (holding an egg
    in front), "flung" (arms thrown up). Returns (root, hand position, held-egg position)."""
    root = empty("Figure", feet, (tilt, 0, yaw))
    skin = mat("skin", lambda: real.gloss("Skin", srgb(245, 205, 150), roughness=0.5))
    cloth = mat(("shirt", shirt), lambda: real.gloss("Shirt", srgb(*shirt), roughness=0.6))
    pants = mat("pants", lambda: real.gloss("Pants", srgb(40, 45, 60), roughness=0.6))
    for side in (-1, 1):
        rbox((0.9, 0.9, 2.0), (side * 0.48, 0, 1.0), pants, 0.12, parent=root)
    rbox((2.0, 1.0, 0.45), (0, 0, 2.2), pants, 0.12, parent=root)
    rbox((2.0, 1.0, 1.6), (0, 0, 3.2), cloth, 0.15, parent=root)
    rbox((1.15, 1.15, 1.15), (0, 0, 4.6), skin, 0.3, parent=root)
    # The figure's right is -X (facing -Y, up +Z).
    hands = {}
    for side in (-1, 1):
        shoulder = Vector((side * 1.5, 0, 3.85))
        if pose == "aim" and side == -1:
            hand = shoulder + Vector((0.2, -1.95, 0.15))
        elif pose == "throw" and side == -1:
            hand = shoulder + Vector((0.1, -1.4, 1.35))
        elif pose == "carry":
            hand = Vector((side * 0.7, -1.35, 2.9))
        elif pose == "flung":
            hand = shoulder + Vector((side * 0.9, 0.3, 1.7))
        else:
            hand = shoulder + Vector((side * 0.25, -0.3, -1.9))
        arm = rbox((0.9, 0.9, 2.0), (shoulder + hand) / 2, skin, 0.12, parent=root)
        arm.rotation_euler = (shoulder - hand).to_track_quat("Z", "Y").to_euler()
        hands[side] = hand
    bpy.context.view_layer.update()
    world = root.matrix_world.copy()
    if jetpack:
        before = set(bpy.data.objects)
        jetpacks.build(2, (0, 0, 3.2), 0.0)
        for obj in set(bpy.data.objects) - before:
            if obj.parent is None:
                obj.matrix_world = world @ obj.matrix_world
            if obj.get("role") == "nozzle" and flame > 0:
                length = 1.8 * flame
                for radius, share, color in ((0.2, 1.0, (1.0, 0.75, 0.35)), (0.09, 0.55, (1.0, 0.95, 0.85))):
                    jet = tube((0, 0, 0), (0, 0, length * share), radius, soft(color, 6), radius2=0.02, vertices=16)
                    jet.matrix_world = obj.matrix_world @ jet.matrix_world
    hand = world @ (hands[-1] + Vector((0, -0.55, 0)) if pose in ("aim", "throw") else hands[-1])
    held = world @ Vector((0, -1.45, 3.0))
    return root, hand, held


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
    l.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0


def lights(target):
    scene = bpy.context.scene
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.0
    sun.angle = math.radians(3)
    sun.color = (1.0, 0.95, 0.88)
    obj = bpy.data.objects.new("Sun", sun)
    obj.rotation_euler = (math.radians(50), math.radians(-25), math.radians(-35))
    scene.collection.objects.link(obj)
    for name, location, energy, colour, size in (
        ("Fill", (24, 10, 10), 9000, (0.6, 0.7, 1.0), 24),
        ("Back", (-18, -50, 16), 12000, (0.75, 0.7, 1.0), 26),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, colour
        data.specular_factor = 0.0
        light = bpy.data.objects.new(name, data)
        light.location = location
        light.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)


def backdrop():
    rock((60, -120, -30), 9, 0.4)
    rock((70, -150, 20), 8, 1.3)
    rock((40, -90, -35), 4, 2.2)


def caption(cam, text, sub):
    font = None
    try:
        font = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
    except RuntimeError:
        pass
    for body, size, y, strength in ((text, 0.085, 0.66, 1.6), (sub, 0.062, 0.56, 1.0)):
        curve = bpy.data.curves.new("Caption", "FONT")
        curve.body = body
        curve.size = size
        curve.align_x = "LEFT"
        if font:
            curve.font = font
        obj = bpy.data.objects.new("Caption", curve)
        bpy.context.scene.collection.objects.link(obj)
        local(obj, cam)
        obj.location = (-1.12, y, -2.0)
        real.assign(obj, real.glow("Caption", (0.85, 0.9, 1.0), strength))


def setup(camera_at, look_at, lens=26):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _cache.clear()
    space()
    lights(look_at)
    backdrop()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 32)):
        if hasattr(scene.eevee, attribute):
            setattr(scene.eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 720, 470
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = 0.2
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = camera_at
    cam.rotation_euler = (Vector(look_at) - Vector(camera_at)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def shoot(name):
    scene = bpy.context.scene
    scene.render.filepath = os.path.join(OUT_DIR, f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("Wrote", scene.render.filepath)


# --- Harpoon -----------------------------------------------------------------------------------

H_CAMERA = ((-16.5, -6.0, 7.0), (-0.6, -9.5, 2.6))
# The carrier flees at 24 studs, turned so the egg in its arms shows.
H_TARGET = Vector((-1.0, -18.0, 0.6))


def harpoon_scene(concept, phase, title, sub):
    cam = setup(*H_CAMERA)
    caption(cam, title, sub)
    _, hand, _ = figure((0, 0, 0), 0.0, "aim")
    flung = phase == 3
    _, _, held = figure(
        H_TARGET + (Vector((0, -1.2, 0.4)) if flung else Vector()),
        math.radians(-65),
        "flung" if flung else "carry",
        shirt=(200, 80, 90),
        tilt=math.radians(-18) if flung else 0.0,
    )
    return hand, held


def wrist_launcher(hand):
    """A short launcher on the wrist: shown only while the harpoon is out."""
    d = Vector((0, -1, 0))
    tube(hand + d * -0.2, hand + d * 0.5, 0.32, steel())
    tube(hand + d * 0.45, hand + d * 0.62, 0.36, glow(CYAN, 5))


def hook(tip, direction, closed=False):
    """The harpoon's head: a pearl shaft, a steel collar, a glowing magnet and three claws."""
    d = Vector(direction).normalized()
    k = HOOK_SCALE
    back = tip - d * 1.9 * k
    tube(back, tip - d * 0.55 * k, 0.16 * k, pearl())
    tube(tip - d * 0.75 * k, tip - d * 0.45 * k, 0.3 * k, steel())
    tube(tip - d * 0.5 * k, tip - d * 0.3 * k, 0.26 * k, glow(CYAN, 6))
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    for i in range(3):
        angle = i * 2 * math.pi / 3 + 0.4
        radial = side * math.cos(angle) + up * math.sin(angle)
        spread = 0.25 if closed else 0.65
        base = tip - d * 0.4 * k + radial * 0.25 * k
        end = tip + d * 0.35 * k + radial * spread * k
        tube(base, end, 0.09 * k, steel(), radius2=0.05 * k, vertices=8)
        ball(0.07 * k, end, glow(CYAN, 5))


# The hook is drawn bigger than a hand-sized prop so it reads at 20-50 studs on a phone.
HOOK_SCALE = 1.6
HOOK_LENGTH = 1.9 * HOOK_SCALE


def cable(a, b, sag=0.0, strength=5.0):
    """The cable (a Beam in game): a thin bright strand, a soft glow round it."""
    a, b = Vector(a), Vector(b)
    if sag <= 0:
        tube(a, b, 0.06, glow(CYAN, strength), vertices=8)
        tube(a, b, 0.18, soft(CYAN, 2.5, 0.6), vertices=16)
        return
    points = []
    for i in range(13):
        t = i / 12
        points.append(a.lerp(b, t) + Vector((0, 0, -sag * 4 * t * (1 - t))))
    for p, q in zip(points, points[1:]):
        tube(p, q, 0.06, glow(CYAN, strength), vertices=8)
        tube(p, q, 0.3, soft(CYAN, 2.5, 0.6), vertices=16)


def trail(a, b, radius, color, alpha=0.8):
    """A Trail behind something in flight: widest at it, gone at the end."""
    tube(b, a, radius, soft(color, 4, alpha), radius2=0.01, vertices=16)


def h1(phase):
    names = {
        1: ("A. Гарпун на тросе — выстрел", "крюк с когтями летит из пускача на запястье, за ним трос-луч"),
        2: ("A. Гарпун на тросе — захват", "когти смыкаются на яйце, вспышка-кольцо"),
        3: ("A. Гарпун на тросе — притяжение", "трос натянут, крюк тащит яйцо к стрелку; промах — крюк пустой назад"),
    }
    hand, held = harpoon_scene("h1", phase, *names[phase])
    wrist_launcher(hand)
    muzzle = hand + Vector((0, -0.62, 0))
    if phase == 1:
        tip = muzzle.lerp(held, 0.45)
        d = held - muzzle
        egg(held, GOLD_EGG, (0, 0.3, 0))
        hook(tip, d)
        cable(muzzle, tip - d.normalized() * HOOK_LENGTH)
        trail(tip - d.normalized() * HOOK_LENGTH, tip - d.normalized() * 10, 0.35, CYAN, 0.5)
        torus(0.5, 0.05, muzzle, glow(CYAN, 6), rotation=(math.pi / 2, 0, 0))
    elif phase == 2:
        d = held - muzzle
        egg(held, GOLD_EGG, (0, 0.3, 0))
        tip = held - d.normalized() * 0.8
        hook(tip, d, closed=True)
        cable(muzzle, tip - d.normalized() * HOOK_LENGTH)
        flash = d.normalized().to_track_quat("Z", "Y").to_euler()
        torus(1.6, 0.07, held, glow(CYAN, 7), rotation=flash)
        torus(2.4, 0.04, held, soft(CYAN, 5, 0.7, "flat"), rotation=flash)
    else:
        at = muzzle.lerp(held, 0.45)
        d = held - muzzle
        egg(at, GOLD_EGG, (0, 0.3, 0))
        tip = at - d.normalized() * 0.8
        hook(tip, d, closed=True)
        cable(muzzle, tip - d.normalized() * HOOK_LENGTH, strength=7)
        trail(at + d.normalized() * 0.8, at + d.normalized() * 7, 0.7, GOLD_EGG, 0.5)


def h2(phase):
    names = {
        1: ("Б. Луч-тягач — выстрел", "луч растёт из ладони конусом, по нему бегут кольца"),
        2: ("Б. Луч-тягач — захват", "кольцо захвата вокруг яйца, яйцо подсвечено"),
        3: ("Б. Луч-тягач — притяжение", "кольца бегут к стрелку и несут яйцо; промах — луч гаснет на 50 studs"),
    }
    hand, held = harpoon_scene("h2", phase, *names[phase])
    d = held - hand
    reach = 0.6 if phase == 1 else 1.0
    end = hand.lerp(held, reach)
    tube(hand, end, 0.25, soft(CYAN, 4, 0.55), radius2=2.0 * reach, vertices=32)
    tube(hand, end, 0.08, soft(WHITE, 5, 0.9), radius2=0.5 * reach, vertices=16)
    rotation = d.normalized().to_track_quat("Z", "Y").to_euler()
    shift = 0.08 if phase == 3 else 0.0
    for i in range(1, 6):
        t = i / 6 * reach - shift
        if t <= 0.02:
            continue
        torus(0.25 + (2.0 - 0.25) * t, 0.05, hand.lerp(held, t), glow(CYAN, 4), rotation=rotation)
    ball(0.45, hand, glow(CYAN, 6))
    if phase == 1:
        egg(held, GOLD_EGG, (0, 0.3, 0))
    elif phase == 2:
        egg(held, GOLD_EGG, (0, 0.3, 0))
        ball(1.5, held, soft(CYAN, 4, 0.9, "rim"))
        torus(2.0, 0.09, held, glow(CYAN, 7), rotation=(math.pi / 2, 0, 0.6))
        torus(2.0, 0.09, held, glow(CYAN, 7), rotation=(0.3, math.pi / 2, 0))
    else:
        at = hand.lerp(held, 0.5)
        egg(at, GOLD_EGG, (0, 0.3, 0))
        ball(1.5, at, soft(CYAN, 4, 0.9, "rim"))


def magnet(center, direction, scale=1.0):
    """A horseshoe magnet flying poles first: pearl body, glowing pole tips."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1))).normalized()
    rotation = d.to_track_quat("Z", "Y")
    bpy.ops.mesh.primitive_torus_add(major_radius=0.7 * scale, minor_radius=0.22 * scale, major_segments=48, minor_segments=12)
    ring = bpy.context.active_object
    mesh = bmesh.new()
    mesh.from_mesh(ring.data)
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if v.co.y > 0.01], context="VERTS")
    mesh.to_mesh(ring.data)
    mesh.free()
    ring.rotation_euler = (rotation @ Euler((math.pi / 2, 0, 0)).to_quaternion()).to_euler()
    ring.location = center - d * 0.2 * scale
    smooth(ring)
    real.assign(ring, pearl())
    for s in (-1, 1):
        base = center + side * s * 0.7 * scale
        tube(base - d * 0.2 * scale, base + d * 0.5 * scale, 0.22 * scale, pearl())
        tube(base + d * 0.5 * scale, base + d * 0.85 * scale, 0.24 * scale, glow(CYAN, 7))


def h3(phase):
    names = {
        1: ("В. Магнит на молнии — выстрел", "магнит-подкова летит, за ним трещит дуга"),
        2: ("В. Магнит на молнии — захват", "магнит прилип к яйцу, вокруг искрят дуги"),
        3: ("В. Магнит на молнии — притяжение", "дуга тянет яйцо к стрелку; промах — дуга рвётся"),
    }
    hand, held = harpoon_scene("h3", phase, *names[phase])
    d = held - hand
    if phase == 1:
        at = hand.lerp(held, 0.5)
        egg(held, GOLD_EGG, (0, 0.3, 0))
        magnet(at, d)
        zigzag(hand, at - d.normalized() * 0.3, 9, 0.6, 0.05, glow(CYAN, 7), 1)
        zigzag(hand, at - d.normalized() * 0.3, 7, 0.9, 0.035, glow(WHITE, 5), 2)
    else:
        at = held if phase == 2 else hand.lerp(held, 0.45)
        egg(at, GOLD_EGG, (0, 0.3, 0))
        magnet(at - d.normalized() * 1.5, d)
        zigzag(hand, at - d.normalized() * 1.8, 11, 0.5, 0.05, glow(CYAN, 7), 3)
        zigzag(hand, at - d.normalized() * 1.8, 8, 0.8, 0.035, glow(WHITE, 5), 4)
        if phase == 2:
            for i in range(4):
                angle = i * math.pi / 2 + 0.3
                off = Vector((math.cos(angle) * 1.8, 0, math.sin(angle) * 1.8))
                zigzag(at + off * 0.45, at + off, 3, 0.25, 0.035, glow(CYAN, 7), 5 + i)


# --- Bomb --------------------------------------------------------------------------------------

B_CAMERA = ((-26.0, 4.0, 15.0), (0.0, -17.0, 1.0))
B_CENTER = Vector((0.0, -27.0, 2.5))
RADIUS = 25.0
VICTIMS = ((Vector((-3.5, -29.5, 0.0)), math.radians(40)), (Vector((4.0, -26.0, -1.0)), math.radians(-50)))


def bomb_scene(phase, title, sub):
    cam = setup(*B_CAMERA, lens=24)
    caption(cam, title, sub)
    _, hand, _ = figure((0, 0, 0), 0.0, "throw")
    for feet, yaw in VICTIMS:
        if phase == 3:
            away = (feet - B_CENTER) * Vector((1, 1, 0))
            away = away.normalized() if away.length > 1e-3 else Vector((1, 0, 0))
            figure(feet + away * 3.5 + Vector((0, 0, 1.2)), yaw, "flung", shirt=(200, 80, 90), tilt=math.radians(-25))
            # Motion streaks behind them.
            for k in (-0.5, 0.5):
                start = feet + Vector((k, 0, 3.0))
                tube(start, start - away * 3.2, 0.08, soft(WHITE, 3, 0.6, "flat"), vertices=8)
        else:
            _, _, held = figure(feet, yaw, "carry", shirt=(200, 80, 90))
            egg(held, GREEN_EGG, (0, 0.3, 0))
    return hand


def flight_point(hand):
    return hand.lerp(B_CENTER, 0.5)


def wave(center, radius, strength=6.0):
    """The blast's reach, drawn: a bright ring in the horizontal plane and a faint shell."""
    torus(radius, 0.35, center, glow(VIOLET, strength))
    torus(radius * 0.97, 1.6, center, soft(VIOLET, 3, 0.2, "flat"), scale=(1, 1, 0.12))
    ball(radius, center, soft(VIOLET, 1.5, 0.22, "rim"))


def gyro(center, scale=1.0, bright=4.0):
    ball(0.75 * scale, center, navy())
    torus(0.76 * scale, 0.07 * scale, center, glow(VIOLET, bright), rotation=(0, 0, 0))
    ball(0.3 * scale, center + Vector((0, 0.62, 0.35)) * scale, glow(VIOLET, bright + 2))
    torus(1.35 * scale, 0.07 * scale, center, glow(VIOLET, bright), rotation=(math.radians(70), 0, math.radians(20)))
    torus(1.35 * scale, 0.07 * scale, center, glow(VIOLET, bright), rotation=(math.radians(-60), math.radians(30), 0))


def b1(phase):
    names = {
        1: ("A. Гироскоп — бросок", "тёмное ядро в двух светящихся кольцах, кольца крутятся, огонёк мигает чаще"),
        2: ("A. Гироскоп — сжатие", "0,15 с: кольца схлопываются в ядро, к нему стягиваются полосы"),
        3: ("A. Гироскоп — волна", "кольцо-волна ровно в радиус удара (25 studs), цели отлетают"),
    }
    hand = bomb_scene(phase, *names[phase])
    if phase == 1:
        at = flight_point(hand)
        gyro(at, 1.5)
        trail(at + (hand - at).normalized() * 0.9, at + (hand - at).normalized() * 7, 0.6, VIOLET, 0.6)
    elif phase == 2:
        gyro(B_CENTER, 0.55, 8)
        ball(1.2, B_CENTER, soft(WHITE, 6, 1.0, "core"))
        for i in range(10):
            angle = i * 2 * math.pi / 10
            radial = Vector((math.cos(angle), math.sin(angle), 0.35 * math.sin(angle * 3)))
            tube(B_CENTER + radial * 11, B_CENTER + radial * 3, 0.03, soft(VIOLET, 5, 0.9, "flat"), radius2=0.25, vertices=8)
    else:
        wave(B_CENTER, RADIUS)
        ball(0.5, B_CENTER, glow(VIOLET, 6))


def b2(phase):
    names = {
        1: ("Б. Чёрная дыра — бросок", "чёрный шарик с диском-воронкой, диск крутится"),
        2: ("Б. Чёрная дыра — воронка", "0,2 с: дыра раздувается, по спирали в неё затягивает свет"),
        3: ("Б. Чёрная дыра — выброс", "дыра лопается, волна до края радиуса, цели отлетают"),
    }
    hand = bomb_scene(phase, *names[phase])
    tilt = (math.radians(70), math.radians(15), 0)
    if phase == 1:
        at = flight_point(hand)
        ball(1.2, at, void())
        ball(1.4, at, soft(VIOLET, 5, 1.0, "rim"))
        torus(2.2, 0.6, at, soft(VIOLET, 6, 0.85, "flat"), rotation=tilt, scale=(1, 1, 0.15))
        trail(at + (hand - at).normalized() * 0.9, at + (hand - at).normalized() * 7, 0.6, VIOLET, 0.6)
    elif phase == 2:
        ball(3.5, B_CENTER, void())
        ball(3.9, B_CENTER, soft(VIOLET, 6, 1.0, "rim"))
        torus(6.0, 1.8, B_CENTER, soft(VIOLET, 6, 0.8, "flat"), rotation=tilt, scale=(1, 1, 0.12))
        for i in range(8):
            angle = i * 2 * math.pi / 8
            radial = Vector((math.cos(angle), math.sin(angle), 0.0))
            swirl = Vector((-math.sin(angle), math.cos(angle), 0.0))
            tube(B_CENTER + radial * 13 + swirl * 4, B_CENTER + radial * 5, 0.03, soft(VIOLET, 5, 0.9, "flat"), radius2=0.3, vertices=8)
    else:
        ball(0.6, B_CENTER, void())
        ball(0.75, B_CENTER, soft(VIOLET, 5, 1.0, "rim"))
        wave(B_CENTER, RADIUS)


def b3(phase):
    names = {
        1: ("В. Плазменная граната — бросок", "перламутровая капсула со светящимся швом, как яйца и киоски"),
        2: ("В. Плазменная граната — вспышка", "яркая вспышка-шар на месте капсулы"),
        3: ("В. Плазменная граната — атом", "три кольца в трёх плоскостях до края радиуса, цели отлетают"),
    }
    hand = bomb_scene(phase, *names[phase])
    if phase == 1:
        at = flight_point(hand)
        d = (B_CENTER - hand).normalized()
        rotation = d.to_track_quat("Z", "Y").to_euler()
        capsule(0.95, 2.6, at, pearl(), rotation=rotation)
        torus(0.96, 0.1, at, glow(VIOLET, 6), rotation=rotation)
        ball(0.3, at + d * 1.35, glow(VIOLET, 8))
        for k in range(3):
            angle = k * 2 * math.pi / 3
            side = Vector((math.cos(angle), 0, math.sin(angle)))
            rbox((0.1, 0.8, 0.6), at - d * 1.0 + side * 0.9, steel(), 0.03, rotation=(0, -angle, 0))
        trail(at - d * 0.9, at - d * 7, 0.6, VIOLET, 0.6)
    elif phase == 2:
        ball(2.5, B_CENTER, soft(WHITE, 8, 1.0, "core"))
        ball(5.0, B_CENTER, soft(VIOLET, 5, 0.9, "core"))
    else:
        torus(RADIUS, 0.35, B_CENTER, glow(VIOLET, 6))
        torus(RADIUS, 0.3, B_CENTER, glow(VIOLET, 5), rotation=(math.pi / 2, 0, math.radians(35)))
        torus(RADIUS, 0.3, B_CENTER, glow(VIOLET, 5), rotation=(math.pi / 2, 0, math.radians(-55)))
        ball(1.0, B_CENTER, glow(VIOLET, 6))


CONCEPT_FUNCTIONS = {"h1": h1, "h2": h2, "h3": h3, "b1": b1, "b2": b2, "b3": b3}

for concept in CONCEPTS:
    for phase in (1, 2, 3):
        CONCEPT_FUNCTIONS[concept](phase)
        shoot(f"{concept}_{phase}")
