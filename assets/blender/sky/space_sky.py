# The space skybox: six cube faces for Roblox's Sky (SkyboxBk/Dn/Ft/Lf/Rt/Up). Deep space with a
# soft band of nebula across the sky, nebula patches in their own colours (as in colour-mapped
# telescope pictures), stars of many sizes with a few big twinkles, and landmarks to steer by,
# spread far apart round the sky and each unlike the others: a ringed planet, a cratered moon, an
# icy cloudy planet, a spiral galaxy, a banded gas giant, a comet, a rust-red planet below and a
# black hole with a glowing disc, lit from the same side as the game's sun (Lighting.ClockTime).
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


def spotted(name, colour, spots, scale, threshold):
    """A soft planet surface in `colour` with patches of `spots` (craters, clouds, dark seas) where
    a noise rises past `threshold`."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 1.0
    coord = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 6.0
    links.new(coord.outputs["Generated"], noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position, cr.elements[0].color = threshold - 0.04, (*colour, 1)
    cr.elements[1].position, cr.elements[1].color = threshold + 0.04, (*spots, 1)
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
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

    # Nebula patches away from the band, each in its own colours, as in colour-mapped telescope
    # pictures (2026-11-10): warm orange and rose; teal and gold; blue and white; green and violet
    # low down. Spread round the sky, clear of the planets and the galaxy.
    for centre, width, strength, offset, palette in (
        ((-0.7, -0.3, -0.4), 0.35, 0.5, (9, 1, 4), [(0.35, (0.85, 0.3, 0.12)), (0.65, (0.9, 0.2, 0.45))]),
        ((0.75, 0.05, -0.15), 0.28, 0.45, (4, 6, 2), [(0.3, (0.08, 0.5, 0.55)), (0.55, (0.2, 0.62, 0.5)), (0.75, (0.9, 0.68, 0.22))]),
        ((-0.3, -0.35, 0.88), 0.3, 0.45, (7, 3, 8), [(0.35, (0.12, 0.25, 0.85)), (0.7, (0.55, 0.75, 1.0))]),
        ((0.3, -0.85, 0.35), 0.32, 0.4, (1, 8, 5), [(0.35, (0.15, 0.6, 0.35)), (0.7, (0.5, 0.25, 0.75))]),
    ):
        patch = math_node("MULTIPLY", spot(centre, width), ramp_value(n, l, noise(3.0, 10, 0.6, offset), 0.4, 0.8))
        patch_tint = ramp(noise(1.5, 3, 0.5, tuple(o * 1.7 for o in offset)), palette)
        sky = mix(sky, scale_colour(patch_tint, math_node("MULTIPLY", patch, strength)), None)
        # A few brighter wisps in each, so it reads as gas, not a smudge.
        patch_wisps = math_node("MULTIPLY", patch, ramp_value(n, l, noise(7.0, 12, 0.7, offset), 0.55, 0.85))
        sky = mix(sky, scale_colour(patch_tint, math_node("MULTIPLY", patch_wisps, strength * 0.8)), None)

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

    # A grey moon with craters (big enough to steer by, 2026-11-10).
    bpy.ops.mesh.primitive_uv_sphere_add(radius=44, segments=64, ring_count=32)
    moon = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    moon.data.materials.append(spotted("Moon", (0.72, 0.7, 0.8), (0.42, 0.4, 0.5), 5.5, 0.62))
    place(moon, (-0.75, 0.38, 0.45), 750)

    # An icy teal planet under white clouds.
    bpy.ops.mesh.primitive_uv_sphere_add(radius=42, segments=64, ring_count=32)
    far = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    far.data.materials.append(spotted("IcePlanet", (0.25, 0.7, 0.85), (0.95, 0.98, 1.0), 2.2, 0.55))
    place(far, (0.1, 0.22, 0.97), 820)


def glowing_card(name, size, build):
    """A flat card facing the centre whose emission and alpha come from `build(nodes, links, uv)`,
    which returns (colour socket, strength socket) and the card draws strength as both glow and
    alpha: the sky shows through where it is faint."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    coord = nodes.new("ShaderNodeTexCoord")
    colour, strength = build(nodes, links, coord.outputs["UV"])
    em = nodes.new("ShaderNodeEmission")
    links.new(colour, em.inputs["Color"])
    glow = nodes.new("ShaderNodeMath")
    glow.operation = "MULTIPLY"
    glow.inputs[1].default_value = 3.0
    links.new(strength, glow.inputs[0])
    links.new(glow.outputs[0], em.inputs["Strength"])
    alpha = nodes.new("ShaderNodeMath")
    alpha.operation = "MINIMUM"
    alpha.inputs[1].default_value = 1.0
    links.new(strength, alpha.inputs[0])
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(alpha.outputs[0], mix.inputs["Fac"])
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(em.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs[0])
    bpy.ops.mesh.primitive_plane_add(size=size)
    card = bpy.context.active_object
    card.data.materials.append(mat)
    return card


def node_math(nodes, links, op, a, b=None):
    m = nodes.new("ShaderNodeMath")
    m.operation = op
    for index, value in enumerate((a, b)):
        if value is None:
            continue
        if isinstance(value, (int, float)):
            m.inputs[index].default_value = value
        else:
            links.new(value, m.inputs[index])
    return m.outputs[0]


def galaxy():
    """A spiral galaxy far off, tilted: a warm core and two blue-violet arms."""
    def build(nodes, links, uv):
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(uv, sep.inputs[0])
        x = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "SUBTRACT", sep.outputs["X"], 0.5), 2.0)
        y = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "SUBTRACT", sep.outputs["Y"], 0.5), 2.0)
        r = node_math(nodes, links, "SQRT", node_math(nodes, links, "ADD", node_math(nodes, links, "MULTIPLY", x, x), node_math(nodes, links, "MULTIPLY", y, y)))
        theta = node_math(nodes, links, "ARCTAN2", y, x)
        # Two arms winding out on a log spiral.
        wind = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "LOGARITHM", node_math(nodes, links, "ADD", r, 0.05), 2.718), 3.2)
        arms = node_math(nodes, links, "COSINE", node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "SUBTRACT", theta, wind), 2.0))
        arms = node_math(nodes, links, "POWER", node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "ADD", arms, 1.0), 0.5), 3.0)
        disc = node_math(nodes, links, "POWER", node_math(nodes, links, "MAXIMUM", node_math(nodes, links, "SUBTRACT", 1.0, r), 0.0), 1.6)
        core = node_math(nodes, links, "POWER", node_math(nodes, links, "MAXIMUM", node_math(nodes, links, "SUBTRACT", 1.0, node_math(nodes, links, "MULTIPLY", r, 3.2)), 0.0), 2.0)
        clumps = nodes.new("ShaderNodeTexNoise")
        clumps.inputs["Scale"].default_value = 9.0
        clumps.inputs["Detail"].default_value = 6.0
        links.new(uv, clumps.inputs["Vector"])
        arms = node_math(nodes, links, "MULTIPLY", arms, node_math(nodes, links, "ADD", node_math(nodes, links, "MULTIPLY", clumps.outputs["Fac"], 0.9), 0.3))
        strength = node_math(nodes, links, "ADD", node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "ADD", node_math(nodes, links, "MULTIPLY", arms, 0.75), 0.12), disc), node_math(nodes, links, "MULTIPLY", core, 1.4))
        tint = nodes.new("ShaderNodeValToRGB")
        tint.color_ramp.elements[0].position, tint.color_ramp.elements[0].color = 0.0, (1.0, 0.88, 0.7, 1)
        tint.color_ramp.elements[1].position, tint.color_ramp.elements[1].color = 0.55, (0.5, 0.58, 1.0, 1)
        e = tint.color_ramp.elements.new(0.3)
        e.color = (0.85, 0.7, 1.0, 1)
        links.new(r, tint.inputs["Fac"])
        return tint.outputs["Color"], strength

    card = glowing_card("Galaxy", 380, build)
    place(card, (-0.45, 0.25, -0.86), 900)
    towards_origin(card)
    # Seen at a slant, an ellipse, turned a little in the sky.
    card.rotation_euler.rotate(Matrix.Rotation(math.radians(62), 3, "X").to_euler())
    card.rotation_euler.rotate_axis("Z", math.radians(28))


def gas_giant():
    """A banded gas giant, cream, orange and rust, low on the far side of the sky from the ringed one."""
    mat = bpy.data.materials.new("GasGiant")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Sheen Weight"].default_value = 0.6
    bsdf.inputs["Sheen Tint"].default_value = (1.0, 0.85, 0.7, 1)
    coord = nodes.new("ShaderNodeTexCoord")
    wobble = nodes.new("ShaderNodeTexNoise")
    wobble.inputs["Scale"].default_value = 3.0
    wobble.inputs["Detail"].default_value = 4.0
    links.new(coord.outputs["Object"], wobble.inputs["Vector"])
    # Broad bands across the planet (object space, ±radius), gently wavy.
    bands = nodes.new("ShaderNodeTexWave")
    bands.wave_type = "BANDS"
    bands.bands_direction = "Z"
    bands.inputs["Scale"].default_value = 0.016
    bands.inputs["Distortion"].default_value = 2.5
    bands.inputs["Detail"].default_value = 1.0
    bands.inputs["Detail Scale"].default_value = 0.5
    links.new(coord.outputs["Object"], bands.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position, cr.elements[0].color = 0.0, (0.95, 0.85, 0.65, 1)
    cr.elements[1].position, cr.elements[1].color = 1.0, (0.55, 0.25, 0.12, 1)
    mid = cr.elements.new(0.5)
    mid.color = (0.95, 0.55, 0.25, 1)
    links.new(bands.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bpy.ops.mesh.primitive_uv_sphere_add(radius=68, segments=96, ring_count=48)
    planet = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    planet.data.materials.append(mat)
    place(planet, (0.85, -0.2, 0.45), 860)
    planet.rotation_euler = (math.radians(14), math.radians(-8), 0)


def comet():
    """A comet high in the sky: a bright head and a long tail pointing away from the sun."""
    direction = blender((-0.35, 0.85, -0.1)).normalized()
    sun = blender(SUN_ROBLOX).normalized()
    distance = 900
    head = direction * distance
    # Away from the sun, as seen on the sky: the tail's direction across the line of sight.
    away = direction - sun
    away = (away - direction * away.dot(direction)).normalized()
    side = direction.cross(away).normalized()
    length, width = 340.0, 90.0

    def build(nodes, links, uv):
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(uv, sep.inputs[0])
        along = sep.outputs["X"]  # 0 at the head, 1 at the tail's end
        across = node_math(nodes, links, "ABSOLUTE", node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "SUBTRACT", sep.outputs["Y"], 0.5), 2.0))
        # The tail narrows towards the head and fades out along its length and to its edges.
        allowed = node_math(nodes, links, "ADD", node_math(nodes, links, "MULTIPLY", along, 0.85), 0.15)
        edge = node_math(nodes, links, "POWER", node_math(nodes, links, "MAXIMUM", node_math(nodes, links, "SUBTRACT", 1.0, node_math(nodes, links, "DIVIDE", across, allowed)), 0.0), 1.5)
        fade = node_math(nodes, links, "POWER", node_math(nodes, links, "SUBTRACT", 1.0, along), 1.6)
        strength = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "MULTIPLY", edge, fade), 0.9)
        tint = nodes.new("ShaderNodeValToRGB")
        tint.color_ramp.elements[0].color = (0.85, 0.97, 1.0, 1)
        tint.color_ramp.elements[1].color = (0.25, 0.6, 1.0, 1)
        links.new(along, tint.inputs["Fac"])
        return tint.outputs["Color"], strength

    mesh = bpy.data.meshes.new("CometTail")
    corners = [head - side * width * 0.5, head + side * width * 0.5, head + away * length + side * width * 0.5, head + away * length - side * width * 0.5]
    mesh.from_pydata([tuple(c) for c in corners], [], [(0, 1, 2, 3)])
    uv = mesh.uv_layers.new()
    for index, value in enumerate([(0, 0), (0, 1), (1, 1), (1, 0)]):
        uv.data[index].uv = value
    tail = bpy.data.objects.new("CometTail", mesh)
    bpy.context.scene.collection.objects.link(tail)
    card = glowing_card("CometGlow", 1, build)
    tail.data.materials.append(card.data.materials[0])
    bpy.data.objects.remove(card)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=7, segments=24, ring_count=12)
    ball = bpy.context.active_object
    ball.data.materials.append(emission("CometHead", (0.9, 0.97, 1.0), 8.0))
    ball.location = head


def red_planet():
    """A small rust-red planet low down: seen when flying and looking below."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=46, segments=64, ring_count=32)
    planet = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    planet.data.materials.append(spotted("RedPlanet", (0.78, 0.3, 0.16), (0.42, 0.12, 0.08), 3.0, 0.6))
    place(planet, (0.2, -0.75, -0.6), 800)


def black_hole():
    """A black hole in front of the blue nebula: a black disc, a thin bright ring round it, and a
    tilted disc of glowing gas (white-hot inside, orange and red outside) passing in front of and
    behind it."""
    direction = (-0.6, -0.45, 0.65)
    distance = 900

    def disc(nodes, links, uv):
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(uv, sep.inputs[0])
        x = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "SUBTRACT", sep.outputs["X"], 0.5), 2.0)
        y = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "SUBTRACT", sep.outputs["Y"], 0.5), 2.0)
        r = node_math(nodes, links, "SQRT", node_math(nodes, links, "ADD", node_math(nodes, links, "MULTIPLY", x, x), node_math(nodes, links, "MULTIPLY", y, y)))
        # Bright just outside the hole, fading out to the rim; nothing inside the hole.
        inner = node_math(nodes, links, "GREATER_THAN", r, 0.3)
        falloff = node_math(nodes, links, "POWER", node_math(nodes, links, "MAXIMUM", node_math(nodes, links, "SUBTRACT", 1.0, node_math(nodes, links, "DIVIDE", node_math(nodes, links, "SUBTRACT", r, 0.3), 0.7)), 0.0), 1.8)
        # Soft swirls of gas: a noise stretched round the disc (radius and a little of the angle).
        swirl_in = nodes.new("ShaderNodeCombineXYZ")
        links.new(node_math(nodes, links, "MULTIPLY", r, 5.0), swirl_in.inputs["X"])
        links.new(node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "ARCTAN2", y, x), 0.6), swirl_in.inputs["Y"])
        swirls = nodes.new("ShaderNodeTexNoise")
        swirls.inputs["Scale"].default_value = 1.5
        swirls.inputs["Detail"].default_value = 3.0
        links.new(swirl_in.outputs[0], swirls.inputs["Vector"])
        swirly = node_math(nodes, links, "ADD", node_math(nodes, links, "MULTIPLY", swirls.outputs["Fac"], 0.6), 0.55)
        strength = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "MULTIPLY", inner, falloff), node_math(nodes, links, "MULTIPLY", swirly, 0.85))
        tint = nodes.new("ShaderNodeValToRGB")
        cr = tint.color_ramp
        cr.elements[0].position, cr.elements[0].color = 0.3, (1.0, 0.95, 0.85, 1)
        cr.elements[1].position, cr.elements[1].color = 0.9, (0.75, 0.12, 0.05, 1)
        mid = cr.elements.new(0.5)
        mid.color = (1.0, 0.55, 0.15, 1)
        links.new(r, tint.inputs["Fac"])
        return tint.outputs["Color"], strength

    def ring(nodes, links, uv):
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(uv, sep.inputs[0])
        x = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "SUBTRACT", sep.outputs["X"], 0.5), 2.0)
        y = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "SUBTRACT", sep.outputs["Y"], 0.5), 2.0)
        r = node_math(nodes, links, "SQRT", node_math(nodes, links, "ADD", node_math(nodes, links, "MULTIPLY", x, x), node_math(nodes, links, "MULTIPLY", y, y)))
        # A thin bright ring at the hole's edge, a soft glow round it.
        sharp = node_math(nodes, links, "POWER", node_math(nodes, links, "MAXIMUM", node_math(nodes, links, "SUBTRACT", 1.0, node_math(nodes, links, "DIVIDE", node_math(nodes, links, "ABSOLUTE", node_math(nodes, links, "SUBTRACT", r, 0.36)), 0.05)), 0.0), 2.0)
        soft = node_math(nodes, links, "MULTIPLY", node_math(nodes, links, "POWER", node_math(nodes, links, "MAXIMUM", node_math(nodes, links, "SUBTRACT", 1.0, node_math(nodes, links, "DIVIDE", node_math(nodes, links, "ABSOLUTE", node_math(nodes, links, "SUBTRACT", r, 0.36)), 0.35)), 0.0), 2.0), 0.35)
        strength = node_math(nodes, links, "ADD", sharp, soft)
        colour = nodes.new("ShaderNodeRGB")
        colour.outputs[0].default_value = (1.0, 0.8, 0.55, 1)
        return colour.outputs[0], strength

    size = 300
    # The glow round the hole, facing us, a little behind it.
    halo = glowing_card("BlackHoleRing", size, ring)
    place(halo, direction, distance + 30)
    towards_origin(halo)
    # The hole itself.
    bpy.ops.mesh.primitive_uv_sphere_add(radius=size * 0.5 * 0.33, segments=48, ring_count=24)
    hole = bpy.context.active_object
    hole.data.materials.append(emission("BlackHole", (0.0, 0.0, 0.0), 0.0))
    place(hole, direction, distance)
    # The disc of gas, tilted, through the hole: its near half in front, its far half behind.
    gas = glowing_card("BlackHoleDisc", size * 1.5, disc)
    place(gas, direction, distance)
    towards_origin(gas)
    gas.rotation_euler.rotate(Matrix.Rotation(math.radians(74), 3, "X").to_euler())
    gas.rotation_euler.rotate_axis("Z", math.radians(-18))


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
    galaxy()
    gas_giant()
    comet()
    red_planet()
    black_hole()
    sunlight()
render()
