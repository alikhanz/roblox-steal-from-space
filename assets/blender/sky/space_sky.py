# The space skybox: six cube faces for Roblox's Sky (SkyboxBk/Dn/Ft/Lf/Rt/Up). Deep space with a
# soft band of nebula across the sky, a warm nebula patch, stars of many sizes with a few big
# twinkles, and distant planets lit from the same side as the game's sun (Lighting.ClockTime).
# The sun itself is not drawn: Roblox draws it (Sky.SunTextureId) where it really shines from.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/sky/space_sky.py -- <outdir> [size] [markers]
# `markers` renders coloured direction markers instead of the sky, to check the face orientation.

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "build/sky")
SIZE = int(ARGS[1]) if len(ARGS) > 1 else 1024
MARKERS = len(ARGS) > 2 and ARGS[2] == "markers"

# The game's sun (Lighting:GetSunDirection() at ClockTime 10, GeographicLatitude 41.73), in Roblox axes.
SUN_ROBLOX = Vector((0.47, 0.82, 0.31))

# Roblox's faces: name, look direction and up direction, in Roblox axes (Y up, -Z forward).
# Checked in Studio with the markers: SkyboxLf shows towards +X and SkyboxRt towards -X, and the
# top and bottom faces are turned a quarter (their image top points to +X and -X).
FACES = [
    ("Ft", (0, 0, -1), (0, 1, 0)),
    ("Bk", (0, 0, 1), (0, 1, 0)),
    ("Lf", (1, 0, 0), (0, 1, 0)),
    ("Rt", (-1, 0, 0), (0, 1, 0)),
    ("Up", (0, 1, 0), (1, 0, 0)),
    ("Dn", (0, -1, 0), (-1, 0, 0)),
]


def blender(v):
    """Roblox axes (Y up, -Z forward) to Blender axes (Z up, Y forward)."""
    x, y, z = v
    return Vector((x, -z, y))


def emission(name, colour, strength=1.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*colour, 1)
    em.inputs["Strength"].default_value = strength
    if alpha < 1:
        mix = nodes.new("ShaderNodeMixShader")
        clear = nodes.new("ShaderNodeBsdfTransparent")
        mix.inputs["Fac"].default_value = alpha
        links.new(clear.outputs[0], mix.inputs[1])
        links.new(em.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs[0])
        mat.blend_method = "BLEND" if hasattr(mat, "blend_method") else None
    else:
        links.new(em.outputs[0], out.inputs[0])
    return mat


def matte(name, colour, rim=None):
    """A soft cartoon planet surface: diffuse, with an optional atmosphere rim."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    if rim:
        bsdf.inputs["Coat Weight"].default_value = 0.0
        bsdf.inputs["Sheen Weight"].default_value = 1.0
        bsdf.inputs["Sheen Tint"].default_value = (*rim, 1)
    return mat


def place(obj, direction, distance):
    obj.location = blender(direction).normalized() * distance


def towards_origin(obj):
    obj.rotation_euler = (-obj.location).to_track_quat("Z", "Y").to_euler()


# --- World: deep space, nebula band, stars ---------------------------------------------------


def world():
    w = bpy.data.worlds.new("Space")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    n, l = nt.nodes, nt.links
    n.clear()
    out = n.new("ShaderNodeOutputWorld")
    bg = n.new("ShaderNodeBackground")
    l.new(bg.outputs[0], out.inputs[0])
    coord = n.new("ShaderNodeTexCoord")
    direction = coord.outputs["Generated"]

    def math_node(op, a, b=None, clamp=False):
        m = n.new("ShaderNodeMath")
        m.operation = op
        m.use_clamp = clamp
        for index, value in enumerate((a, b)):
            if value is None:
                continue
            if isinstance(value, (int, float)):
                m.inputs[index].default_value = value
            else:
                l.new(value, m.inputs[index])
        return m.outputs[0]

    def noise(scale, detail, roughness, offset=(0, 0, 0)):
        add = n.new("ShaderNodeVectorMath")
        add.operation = "ADD"
        l.new(direction, add.inputs[0])
        add.inputs[1].default_value = offset
        t = n.new("ShaderNodeTexNoise")
        t.inputs["Scale"].default_value = scale
        t.inputs["Detail"].default_value = detail
        t.inputs["Roughness"].default_value = roughness
        l.new(add.outputs[0], t.inputs["Vector"])
        return t.outputs["Fac"]

    def ramp(fac, stops):
        r = n.new("ShaderNodeValToRGB")
        cr = r.color_ramp
        cr.elements[0].position, cr.elements[0].color = stops[0][0], (*stops[0][1], 1)
        cr.elements[1].position, cr.elements[1].color = stops[-1][0], (*stops[-1][1], 1)
        for position, colour in stops[1:-1]:
            e = cr.elements.new(position)
            e.color = (*colour, 1)
        l.new(fac, r.inputs["Fac"])
        return r.outputs["Color"]

    def band(axis, width):
        """1 on the great circle across `axis`, fading to 0 at `width` away."""
        dot = n.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        l.new(direction, dot.inputs[0])
        dot.inputs[1].default_value = tuple(blender(axis).normalized())
        a = math_node("ABSOLUTE", dot.outputs["Value"])
        return math_node("SUBTRACT", 1.0, math_node("DIVIDE", a, width), clamp=True)

    def spot(centre, width):
        """1 towards `centre`, fading to 0 at `width` (in 1 - cos)."""
        dot = n.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        l.new(direction, dot.inputs[0])
        dot.inputs[1].default_value = tuple(blender(centre).normalized())
        return math_node("SUBTRACT", 1.0, math_node("DIVIDE", math_node("SUBTRACT", 1.0, dot.outputs["Value"]), width), clamp=True)

    def mix(a, b, fac, blend="ADD"):
        m = n.new("ShaderNodeMix")
        m.data_type = "RGBA"
        m.blend_type = blend
        m.inputs["Factor"].default_value = 1.0
        if fac is not None:
            if isinstance(fac, (int, float)):
                m.inputs["Factor"].default_value = fac
            else:
                l.new(fac, m.inputs["Factor"])
        l.new(a, m.inputs[6])
        l.new(b, m.inputs[7])
        return m.outputs[2]

    def scale_colour(colour, fac):
        m = n.new("ShaderNodeMix")
        m.data_type = "RGBA"
        m.blend_type = "MULTIPLY"
        m.inputs["Factor"].default_value = 1.0
        l.new(colour, m.inputs[6])
        if isinstance(fac, (int, float)):
            m.inputs[7].default_value = (fac, fac, fac, 1)
        else:
            l.new(fac, m.inputs[7])
        return m.outputs[2]

    def rgb(c):
        node = n.new("ShaderNodeRGB")
        node.outputs[0].default_value = (*c, 1)
        return node.outputs[0]

    # Base: deep navy, a touch lighter and bluer along the galactic band.
    galaxy_axis = (0.35, 0.55, -0.76)
    glow_band = band(galaxy_axis, 0.55)
    base = mix(rgb((0.004, 0.005, 0.018)), scale_colour(rgb((0.03, 0.035, 0.11)), math_node("POWER", glow_band, 1.5)), None)

    # Nebula clouds along the band: violet, magenta and teal, broken up by noise.
    cloud = math_node("MULTIPLY", glow_band, ramp_value(n, l, noise(2.2, 10, 0.62), 0.42, 0.78))
    tint = ramp(noise(1.1, 3, 0.5, (5, 2, 1)), [
        (0.30, (0.30, 0.08, 0.55)),
        (0.50, (0.75, 0.16, 0.55)),
        (0.70, (0.10, 0.45, 0.75)),
    ])
    sky = mix(base, scale_colour(tint, math_node("MULTIPLY", cloud, 0.55)), None)
    # Bright wisps inside the clouds.
    wisps = math_node("MULTIPLY", cloud, ramp_value(n, l, noise(6.0, 12, 0.7, (3, 3, 3)), 0.55, 0.85))
    sky = mix(sky, scale_colour(rgb((0.9, 0.6, 1.0)), math_node("MULTIPLY", wisps, 0.35)), None)

    # A warm nebula patch away from the band (orange and rose), low in the sky opposite the sun.
    warm = math_node("MULTIPLY", spot((-0.6, 0.15, -0.55), 0.35), ramp_value(n, l, noise(3.0, 10, 0.6, (9, 1, 4)), 0.4, 0.8))
    warm_tint = ramp(noise(1.5, 3, 0.5, (2, 7, 3)), [(0.35, (0.85, 0.3, 0.12)), (0.65, (0.9, 0.2, 0.45))])
    sky = mix(sky, scale_colour(warm_tint, math_node("MULTIPLY", warm, 0.5)), None)

    # Stars: three layers of Voronoi points, more of them inside the band.
    for scale, radius, keep, strength in ((140, 0.10, 0.55, 1.6), (60, 0.07, 0.25, 3.0), (22, 0.05, 0.12, 6.0)):
        v = n.new("ShaderNodeTexVoronoi")
        v.inputs["Scale"].default_value = scale
        l.new(direction, v.inputs["Vector"])
        dot = math_node("SUBTRACT", 1.0, math_node("DIVIDE", v.outputs["Distance"], radius), clamp=True)
        dot = math_node("POWER", dot, 2.0)
        # Keep a share of the cells, by the cell's random colour.
        sep = n.new("ShaderNodeSeparateColor")
        l.new(v.outputs["Color"], sep.inputs[0])
        share = math_node("ADD", keep, math_node("MULTIPLY", glow_band, keep))
        alive = math_node("LESS_THAN", sep.outputs[0], share)
        star = math_node("MULTIPLY", dot, alive)
        hue = mix(rgb((1.0, 1.0, 1.0)), v.outputs["Color"], 0.25, "MIX")
        sky = mix(sky, scale_colour(hue, math_node("MULTIPLY", star, strength)), None)

    l.new(sky, bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0


def ramp_value(n, l, fac, low, high):
    """Map `fac` from [low, high] to [0, 1], clamped, smooth."""
    m = n.new("ShaderNodeMapRange")
    m.interpolation_type = "SMOOTHSTEP"
    m.inputs["From Min"].default_value = low
    m.inputs["From Max"].default_value = high
    l.new(fac, m.inputs["Value"])
    return m.outputs["Result"]


# --- Objects: twinkle stars and planets ---------------------------------------------------------


def twinkles():
    """Big four-point sparkle stars, flat cards facing the centre."""
    rng = random.Random(7)
    mat = emission("Twinkle", (1.0, 0.95, 0.9), 6.0)
    for index in range(18):
        theta = rng.uniform(0, math.tau)
        y = rng.uniform(-0.3, 0.95)
        r = math.sqrt(1 - y * y)
        direction = (math.cos(theta) * r, y, math.sin(theta) * r)
        size = rng.uniform(4, 9)
        for spoke in range(2):
            bpy.ops.mesh.primitive_plane_add(size=1)
            card = bpy.context.active_object
            card.data.materials.append(mat)
            place(card, direction, 900)
            towards_origin(card)
            card.scale = (size * 0.07, size, 1) if spoke == 0 else (size, size * 0.07, 1)


def planets():
    """Distant planets: a big ringed one, a small moon-like one and a far teal one."""
    big = (0.55, 0.32, -0.77)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=70, segments=96, ring_count=48)
    p = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    p.data.materials.append(matte("RingedPlanet", (0.85, 0.45, 0.6), (1.0, 0.7, 0.9)))
    place(p, big, 800)
    bpy.ops.mesh.primitive_torus_add(major_radius=118, minor_radius=26, major_segments=128, minor_segments=8)
    ring = bpy.context.active_object
    ring.scale = (1, 1, 0.04)
    ring.data.materials.append(matte("Ring", (1.0, 0.85, 0.6)))
    place(ring, big, 800)
    ring.rotation_euler = (math.radians(68), math.radians(18), math.radians(25))

    bpy.ops.mesh.primitive_uv_sphere_add(radius=26, segments=64, ring_count=32)
    moon = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    moon.data.materials.append(matte("Moon", (0.7, 0.68, 0.85)))
    place(moon, (-0.75, 0.38, 0.45), 750)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=16, segments=48, ring_count=24)
    far = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    far.data.materials.append(matte("FarPlanet", (0.25, 0.75, 0.8), (0.6, 1.0, 1.0)))
    place(far, (0.1, 0.22, 0.97), 820)


def sunlight():
    data = bpy.data.lights.new("Sun", "SUN")
    data.energy = 4.0
    data.color = (1.0, 0.95, 0.88)
    sun = bpy.data.objects.new("Sun", data)
    bpy.context.scene.collection.objects.link(sun)
    # A sun lamp shines along its -Z: point its +Z at the sun.
    sun.rotation_euler = blender(SUN_ROBLOX).to_track_quat("Z", "Y").to_euler()


def markers():
    """A coloured ball in each Roblox direction, and a white one off-centre towards +X on each
    face, so the face orientation can be checked in Studio."""
    w = bpy.data.worlds.new("Grey")
    bpy.context.scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.06, 1)
    colours = {
        (1, 0, 0): (1, 0, 0), (-1, 0, 0): (0, 1, 1),
        (0, 1, 0): (0, 1, 0), (0, -1, 0): (1, 0, 1),
        (0, 0, 1): (0, 0, 1), (0, 0, -1): (1, 1, 0),
    }
    for d, c in colours.items():
        bpy.ops.mesh.primitive_uv_sphere_add(radius=60)
        s = bpy.context.active_object
        s.data.materials.append(emission("M", c, 2))
        place(s, d, 500)
        # A white ball off towards +X (or +Z on the X faces) shows each face's rotation.
        side = (0, 0, 1) if d[0] != 0 else (1, 0, 0)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=25)
        t = bpy.context.active_object
        t.data.materials.append(emission("W", (1, 1, 1), 2))
        t.location = blender(d) * 500 + blender(side) * 150


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    for attribute, value in (("taa_render_samples", 64),):
        if hasattr(scene.eevee, attribute):
            setattr(scene.eevee, attribute, value)
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.angle = math.pi / 2
    cam_data.clip_end = 5000
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, look, up in FACES:
        forward, top = blender(look), blender(up)
        z = -forward
        x = top.cross(z)
        rotation = Matrix((x, top, z)).transposed()
        cam.matrix_world = rotation.to_4x4()
        scene.render.filepath = f"{OUT_DIR}/sky_{name}.png"
        bpy.ops.render.render(write_still=True)
        print("Wrote", scene.render.filepath)


bpy.ops.wm.read_factory_settings(use_empty=True)
if MARKERS:
    markers()
else:
    world()
    twinkles()
    planets()
    sunlight()
render()
