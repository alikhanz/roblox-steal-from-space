# Concept sheet: the star serpent (docs/plans/STAR_SERPENT.md; POLISH queue, item 7). Three
# directions, one sheet each, four shots: the whole serpent from the front, from the side, its
# head close up, and from behind and above (how a chasing player sees it: it flees). A player
# stands by the head for scale. The serpent carries the star egg (a rare capsule, decision 088)
# where everyone can see it, flees, loses the egg after three hits on its head, then guards it.
#
# Sizes are the game's, in studs: a head about 14 long, 18 segments 6 apart, 9 thick at the neck
# down to 3 at the tail (SerpentLooks). In the game the body is a chain of one segment shape copied
# along the path the head flies (SerpentController), so every direction is built that way here.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/serpent/concept_serpent.py -- <out.png> <constellation|mech|eel>
# The output path must be absolute (Blender resolves a relative one elsewhere).

import math
import os
import random
import sys

import bpy
import numpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "guardians"))

from guardian_sheet import fit, made  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "concept_serpent.png")
STYLE = ARGS[1] if len(ARGS) > 1 else "constellation"

SEGMENTS = 18
SPACING = 6.0
FIRST = 9.0
LAST = 3.0
# Where the body starts behind the head's middle.
NECK = 7.0
TILE = (1400, 800)

NIGHT = (0.018, 0.016, 0.075)
INDIGO = (0.05, 0.03, 0.22)
VIOLET = (0.16, 0.08, 0.55)
LILAC = (0.45, 0.38, 0.9)
STAR = (1.0, 0.82, 0.35)
PEARL = (0.85, 0.87, 0.92)
DARK = (0.02, 0.02, 0.035)
CYAN = (0.25, 0.8, 1.0)
RARE_BLUE = (0.05, 0.27, 1.0)
STEEL = (0.7, 0.72, 0.8)


# --- Materials -------------------------------------------------------------------------------------


def material(name, color, roughness=0.35, metallic=0.0, emission=0.0, coat=0.4):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Coat Weight"].default_value = coat
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*color, 1.0)
    return mat


def neon(name, color, strength=10.0):
    return material(name, color, emission=strength, coat=0.0)


def fading(name, color, strength=6.0):
    """Glow fading out along the object's local Z: a comet's or a jet's tail (a Trail or a Beam in
    the game, never a solid cone)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    coords = nodes.new("ShaderNodeTexCoord")
    split = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (1, 1, 1, 1)
    ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*color, 1.0)
    emit.inputs["Strength"].default_value = strength
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(coords.outputs["Generated"], split.inputs["Vector"])
    links.new(split.outputs["Z"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(emit.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


# --- Shapes ----------------------------------------------------------------------------------------


def sphere(location, scale, mat, rotation=(0, 0, 0), segments=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = scale
    smooth(obj)
    assign(obj, mat)
    return obj


def ico(location, radius, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location)
    obj = bpy.context.active_object
    assign(obj, mat)
    return obj


def spike(base, tip, radius, mat, vertices=10):
    base, tip = Vector(base), Vector(tip)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0, depth=(tip - base).length, location=(base + tip) / 2)
    obj = bpy.context.active_object
    obj.rotation_euler = (tip - base).to_track_quat("Z", "Y").to_euler()
    smooth(obj)
    assign(obj, mat)
    return obj


def frustum(base, tip, r1, r2, mat, vertices=16):
    base, tip = Vector(base), Vector(tip)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=(tip - base).length, location=(base + tip) / 2)
    obj = bpy.context.active_object
    obj.rotation_euler = (tip - base).to_track_quat("Z", "Y").to_euler()
    smooth(obj)
    assign(obj, mat)
    return obj


def rod(a, b, radius, mat, vertices=8):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b - a).length, location=(a + b) / 2)
    obj = bpy.context.active_object
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    smooth(obj)
    assign(obj, mat)
    return obj


def ring(location, major, minor, mat, axis):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=40, minor_segments=10, location=location)
    obj = bpy.context.active_object
    obj.rotation_euler = Vector(axis).to_track_quat("Z", "Y").to_euler()
    smooth(obj)
    assign(obj, mat)
    return obj


def fin(points, thickness, mat):
    """A thin flat fin through the closed outline `points` (world space)."""
    mesh = bpy.data.meshes.new("Fin")
    mesh.from_pydata([Vector(p) for p in points], [], [list(range(len(points)))])
    obj = bpy.data.objects.new("Fin", mesh)
    bpy.context.scene.collection.objects.link(obj)
    mod = obj.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 0
    assign(obj, mat)
    return obj


# --- Frames along the body --------------------------------------------------------------------------


class Frame:
    """+X along the body towards the tail, +Z up as far as it can be; `at` maps local offsets."""

    def __init__(self, position, tangent, tilt=0.0):
        x = Vector(tangent).normalized()
        z = Vector((0, 0, 1))
        y = z.cross(x).normalized()
        z = x.cross(y)
        self.rot = Matrix((x, y, z)).transposed() @ Matrix.Rotation(tilt, 3, "X")
        self.origin = Vector(position)

    def at(self, x, y=0.0, z=0.0):
        return self.origin + self.rot @ Vector((x, y, z))

    def dir(self, x, y=0.0, z=0.0):
        return self.rot @ Vector((x, y, z))

    def euler(self, extra=None):
        return (self.rot @ extra if extra is not None else self.rot).to_euler()


def path(s):
    """The spine `s` studs behind the neck: a wide S across and a slow rise and fall."""
    return Vector((s * 0.93, 9.0 * math.sin(s / 15.0), 4.0 * math.sin(s / 20.0 + 0.5)))


def tangent(s):
    return (path(s + 0.5) - path(s - 0.5)).normalized()


def segments():
    result = []
    for i in range(SEGMENTS):
        s = i * SPACING
        size = FIRST + (LAST - FIRST) * i / (SEGMENTS - 1)
        result.append((i, Frame(path(s), tangent(s)), size))
    return result


def tail_frame():
    s = (SEGMENTS - 1) * SPACING
    return Frame(path(s), tangent(s))


def head_frame():
    return Frame(path(0) - tangent(0) * NECK, tangent(0))


# --- The star egg (a rare capsule, decision 088) ----------------------------------------------------


def star_egg(c, k=1.0):
    pearl = material("EggPearl", PEARL, roughness=0.2)
    cap = material("EggCap", RARE_BLUE, roughness=0.2)
    glow = neon("EggGlow", (0.45, 0.65, 1.0), 8)
    gold = neon("EggStar", STAR, 14)
    c = Vector(c)
    sphere(c + Vector((0, 0, -0.25 * k)), (1.6 * k, 1.6 * k, 1.75 * k), pearl)
    sphere(c + Vector((0, 0, 0.45 * k)), (1.5 * k, 1.5 * k, 1.6 * k), cap)
    ring(c + Vector((0, 0, 0.2 * k)), 1.6 * k, 0.12 * k, glow, (0, 0, 1))
    ring(c, 2.15 * k, 0.11 * k, glow, (0, 0, 1))
    # The star egg's sparkle (its extra luck): gold specks round it.
    rng = random.Random(4)
    for _ in range(8):
        a = rng.uniform(0, math.tau)
        z = rng.uniform(-1.4, 2.4)
        ico(c + Vector((math.cos(a) * 2.7, math.sin(a) * 2.7, z)) * k, 0.24 * k, gold)


def egg_cradle(frame, height, prong, glow, k=1.0):
    """The egg riding on the back of the first segment, held by prongs: seen from above and from
    behind, where a chasing player is."""
    centre = frame.at(0, 0, height)
    ring(centre + Vector((0, 0, -2.2 * k)), 2.4 * k, 0.4 * k, prong, (0, 0, 1))
    ring(centre + Vector((0, 0, -2.2 * k)), 2.45 * k, 0.15 * k, glow, (0, 0, 1))
    for n in range(5):
        a = n / 5 * math.tau + 0.3
        base = centre + Vector((math.cos(a) * 2.4, math.sin(a) * 2.4, -2.2)) * k
        top = centre + Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, 1.4)) * k
        spike(base, top, 0.35 * k, prong, vertices=6)
    rod(frame.at(0, 0, height - 2.3 * k), frame.at(0, 0, FIRST * 0.35), 0.8 * k, prong)
    star_egg(centre, 0.85 * k)


# --- Direction A: the constellation dragon ----------------------------------------------------------


def constellation_body():
    hide = material("Hide", NIGHT, roughness=0.22, coat=0.9)
    belly = material("Belly", VIOLET, roughness=0.3)
    star = neon("Star", STAR, 16)
    line = neon("Line", LILAC, 6)
    horn = material("Horn", (0.78, 0.74, 0.98), roughness=0.15, metallic=0.5)
    rng = random.Random(7)
    backs = []
    for i, f, size in segments():
        r = size / 2
        sphere(f.at(0), (r * 0.85, r, r * 0.95), hide, f.euler())
        sphere(f.at(0, 0, -r * 0.38), (r * 0.75, r * 0.78, r * 0.6), belly, f.euler())
        # Stars on the back, joined into a constellation down the spine; more on the flanks.
        spot = f.at(rng.uniform(-0.2, 0.2) * r, rng.uniform(-0.4, 0.4) * r, r * 0.93)
        ico(spot, max(0.35, r * 0.14), star)
        backs.append(spot)
        side = 1 if i % 2 == 0 else -1
        ico(f.at(0, side * r * 0.88, r * 0.35), max(0.25, r * 0.09), star)
        # A small crystal dorsal spike between the stars.
        if i % 2 == 1:
            spike(f.at(0, 0, r * 0.8), f.at(r * 0.6, 0, r * 1.5), r * 0.16, horn, vertices=4)
    for a, b in zip(backs, backs[1:]):
        rod(a, b, 0.12, line, vertices=6)
    # The tail's tip and a comet's tail behind it (a Trail in the game).
    t = tail_frame()
    spike(t.at(LAST * 0.3), t.at(LAST * 2.4), LAST * 0.42, hide, vertices=16)
    frustum(t.at(LAST * 1.6), t.at(LAST * 1.6 + 26), 1.6, 3.2, fading("Comet", LILAC, 5), vertices=24)
    egg_cradle(segments()[0][1], FIRST * 0.5 + 3.4, horn, neon("CradleGlow", STAR, 10))


def constellation_head():
    hide = material("Hide", NIGHT, roughness=0.22, coat=0.9)
    belly = material("Belly", VIOLET, roughness=0.3)
    horn = material("Horn", (0.78, 0.74, 0.98), roughness=0.15, metallic=0.5)
    eye = neon("Eye", (1.0, 0.8, 0.2), 22)
    maw = neon("Maw", (1.0, 0.55, 0.2), 8)
    star = neon("Star", STAR, 16)
    edge = neon("Line", LILAC, 6)
    h = head_frame()
    down = Matrix.Rotation(0.12, 3, "Y")
    # Skull, a long wedge of a snout, an open jaw with a glowing throat.
    sphere(h.at(1.2, 0, 0.9), (5.4, 4.3, 3.7), hide, h.euler())
    sphere(h.at(-4.4, 0, 0.2), (4.6, 3.0, 2.1), hide, h.euler(down))
    sphere(h.at(-3.4, 0, -2.0), (4.4, 2.6, 1.0), belly, h.euler(Matrix.Rotation(-0.22, 3, "Y")))
    sphere(h.at(-3.6, 0, -1.0), (3.6, 2.2, 0.5), maw, h.euler())
    for side in (-1, 1):
        # Brow ridges sloping down to the snout: a frown.
        rod(h.at(-5.0, side * 1.4, 2.0), h.at(-1.0, side * 3.4, 3.4), 0.7, horn, vertices=10)
        sphere(h.at(-2.9, side * 2.75, 1.6), (1.5, 0.5, 0.6), eye, h.euler(Matrix.Rotation(-side * 0.35, 3, "X") @ Matrix.Rotation(0.2, 3, "Z")))
        # Two swept horns a side.
        spike(h.at(1.0, side * 2.4, 3.4), h.at(10.5, side * 5.2, 7.0), 1.0, horn, vertices=12)
        spike(h.at(3.0, side * 3.4, 2.2), h.at(9.5, side * 6.8, 3.4), 0.6, horn, vertices=10)
        # Fangs and a fin of light at each cheek (a Beam in the game).
        spike(h.at(-7.6, side * 1.4, -0.9), h.at(-7.8, side * 1.3, -2.6), 0.35, horn, vertices=6)
        fin([h.at(0.5, side * 3.9, -0.6), h.at(6.5, side * 8.2, -1.6), h.at(4.5, side * 4.0, 0.6)], 0.15, edge)
        ico(h.at(-8.6, side * 0.9, 0.9), 0.3, maw)
    for k in range(4):
        ico(h.at(-1.0 + k * 2.0, 0, 4.4 - k * 0.15), 0.45, star)


# --- Direction B: the mech wyrm (the robo style of the pets and guardians) --------------------------


def mech_body():
    shell = material("Ceramic", PEARL, roughness=0.18, coat=0.9)
    plate = material("Plate", VIOLET, roughness=0.25, coat=0.8)
    joint = material("Joint", DARK, roughness=0.4)
    seam = neon("Seam", CYAN, 9)
    metal = material("Spike", STEEL, roughness=0.15, metallic=1.0)
    star = neon("Star", STAR, 16)
    for i, f, size in segments():
        r = size / 2
        sphere(f.at(0), (r * 0.8, r, r), shell, f.euler())
        sphere(f.at(0, 0, r * 0.3), (r * 0.72, r * 0.84, r * 0.78), plate, f.euler())
        ring(f.at(r * 0.6), r * 0.74, max(0.14, r * 0.06), seam, f.dir(1))
        sphere(f.at(SPACING / 2), (r * 0.5, r * 0.64, r * 0.64), joint, f.euler())
        spike(f.at(0, 0, r * 0.85), f.at(r * 0.7, 0, r * 1.7), r * 0.22, metal, vertices=4)
        if i % 3 == 2:
            for side in (-1, 1):
                ico(f.at(0, side * r * 0.98), max(0.3, r * 0.11), star)
    # The tail: a thruster (Beams in the game).
    t = tail_frame()
    frustum(t.at(LAST * 0.4), t.at(LAST * 1.8), LAST * 0.55, LAST * 0.35, joint)
    ring(t.at(LAST * 1.8), LAST * 0.4, 0.15, seam, t.dir(1))
    frustum(t.at(LAST * 1.8), t.at(LAST * 1.8 + 16), 0.6, 1.4, fading("Jet", CYAN, 6), vertices=20)
    egg_cradle(segments()[0][1], FIRST * 0.5 + 3.4, joint, seam)


def mech_head():
    shell = material("Ceramic", PEARL, roughness=0.18, coat=0.9)
    plate = material("Plate", VIOLET, roughness=0.25, coat=0.8)
    joint = material("Joint", DARK, roughness=0.4)
    visor = material("Visor", DARK, roughness=0.05, coat=1.0)
    metal = material("Spike", STEEL, roughness=0.15, metallic=1.0)
    eye = neon("Eye", (1.0, 0.8, 0.2), 22)
    seam = neon("Seam", CYAN, 9)
    star = neon("Star", STAR, 16)
    h = head_frame()
    # A helmet, a crest plate, a visor band wrapping the front, a heavy jaw.
    sphere(h.at(0.6, 0, 0.6), (6.4, 5.0, 4.3), shell, h.euler())
    sphere(h.at(0.4, 0, 2.3), (5.8, 4.5, 2.8), plate, h.euler())
    sphere(h.at(-3.3, 0, -2.6), (4.4, 3.8, 1.7), plate, h.euler(Matrix.Rotation(-0.12, 3, "Y")))
    sphere(h.at(-4.1, 0, 1.0), (2.2, 4.3, 1.7), visor, h.euler())
    ring(h.at(1.6, 0, 0.6), 4.6, 0.25, seam, h.dir(1))
    for side in (-1, 1):
        # Slit eyes slanted to the middle under V brows (the guardians' frown, decision 090).
        sphere(h.at(-6.1, side * 1.8, 1.1), (0.3, 1.2, 0.42), eye, h.euler(Matrix.Rotation(side * 0.35, 3, "X")))
        rod(h.at(-6.3, side * 0.3, 1.9), h.at(-5.6, side * 3.6, 3.2), 0.45, metal)
        # Antenna horns with star tips.
        rod(h.at(2.0, side * 2.6, 3.6), h.at(8.0, side * 4.4, 8.2), 0.32, metal)
        ico(h.at(8.0, side * 4.4, 8.2), 0.7, star)
        # Fangs from the jaw, cheek vents.
        spike(h.at(-7.0, side * 1.7, -2.0), h.at(-7.2, side * 1.7, 0.0), 0.45, metal, vertices=6)
        fin([h.at(1.0, side * 4.6, 0.5), h.at(6.5, side * 8.0, 2.5), h.at(5.0, side * 4.6, -0.8)], 0.3, plate)
        rod(h.at(1.0, side * 4.6, 0.5), h.at(6.5, side * 8.0, 2.5), 0.14, seam, vertices=6)
    rod(h.at(-1.0, 0, 4.0), h.at(5.0, 0, 5.4), 0.5, joint)


# --- Direction C: the comet eel ---------------------------------------------------------------------


def eel_body():
    skin = material("Skin", (0.08, 0.05, 0.3), roughness=0.2, coat=1.0)
    under = material("Under", (0.55, 0.45, 0.95), roughness=0.3)
    sail = material("Sail", (0.3, 0.22, 0.85), roughness=0.2, coat=0.0)
    edge = neon("Edge", (0.75, 0.6, 1.0), 9)
    star = neon("Star", STAR, 16)
    for i, f, size in segments():
        r = size / 2
        sphere(f.at(0), (SPACING * 0.75, r, r * 0.92), skin, f.euler())
        sphere(f.at(0, 0, -r * 0.4), (SPACING * 0.7, r * 0.75, r * 0.55), under, f.euler())
        # A sail of a dorsal fin with a lit edge (a Beam in the game).
        p0, p1, p2 = f.at(-SPACING * 0.45, 0, r * 0.75), f.at(SPACING * 0.15, 0, r * 0.75 + r * 1.3), f.at(SPACING * 0.55, 0, r * 0.75)
        fin([p0, p1, p2], 0.18, sail)
        rod(p0, p1, 0.13, edge, 6)
        rod(p1, p2, 0.13, edge, 6)
        if i % 2 == 1:
            for side in (-1, 1):
                ico(f.at(0, side * r * 0.92, r * 0.2), max(0.25, r * 0.1), star)
    t = tail_frame()
    a = t.at(LAST)
    fin([a, t.at(LAST + 9, 0, 6), t.at(LAST + 6), t.at(LAST + 9, 0, -6)], 0.2, sail)
    rod(a, t.at(LAST + 9, 0, 6), 0.15, edge, 6)
    rod(a, t.at(LAST + 9, 0, -6), 0.15, edge, 6)


def eel_head():
    skin = material("Skin", (0.08, 0.05, 0.3), roughness=0.2, coat=1.0)
    under = material("Under", (0.55, 0.45, 0.95), roughness=0.3)
    sail = material("Sail", (0.3, 0.22, 0.85), roughness=0.2, coat=0.0)
    edge = neon("Edge", (0.75, 0.6, 1.0), 9)
    eye = neon("Eye", (0.4, 1.0, 0.9), 22)
    teeth = material("Teeth", PEARL, roughness=0.2)
    maw = neon("Maw", (1.0, 0.55, 0.25), 8)
    h = head_frame()
    sphere(h.at(1.0, 0, 1.0), (6.5, 4.4, 3.4), skin, h.euler())
    sphere(h.at(-3.6, 0, 1.6), (4.6, 3.4, 1.8), skin, h.euler(Matrix.Rotation(0.25, 3, "Y")))
    sphere(h.at(-3.2, 0, -2.7), (4.4, 3.0, 1.4), under, h.euler(Matrix.Rotation(-0.3, 3, "Y")))
    sphere(h.at(-1.0, 0, -0.6), (2.8, 2.6, 2.2), maw, h.euler())
    for side in (-1, 1):
        sphere(h.at(-1.8, side * 3.4, 2.6), (1.1, 0.5, 1.0), eye, h.euler())
        for k in range(3):
            spike(h.at(-6.2 + k * 1.6, side * (1.6 + k * 0.5), 0.8), h.at(-6.2 + k * 1.6, side * (1.6 + k * 0.5), -0.8), 0.35, teeth, 6)
            spike(h.at(-5.8 + k * 1.6, side * (1.5 + k * 0.5), -2.0), h.at(-5.8 + k * 1.6, side * (1.5 + k * 0.5), -0.6), 0.35, teeth, 6)
        rod(h.at(-6.0, side * 2.0, 1.4), h.at(-3.0, side * 8.0, -2.0), 0.15, edge, 6)
        b = h.at(4.0, side * 4.0, -0.5)
        fin([b, h.at(9.5, side * 9.5, -2.5), h.at(7.0, side * 4.0, -1.5)], 0.15, sail)
    star_egg(h.at(-6.4, 0, -0.6), 0.8)


# --- A player for scale -----------------------------------------------------------------------------


def player():
    grey = material("Player", (0.55, 0.57, 0.62), roughness=0.5)
    pack = material("Pack", (0.25, 0.27, 0.32), roughness=0.4)
    a = head_frame().at(-6, 11, -4)
    sphere(a + Vector((0, 0, 1.6)), (1.0, 0.6, 1.3), grey)
    sphere(a + Vector((0, 0, 3.4)), (0.6, 0.6, 0.6), grey)
    sphere(a + Vector((0, 0.8, 1.8)), (0.6, 0.45, 0.9), pack)
    rod(a + Vector((-0.4, 0, 0.5)), a + Vector((-0.4, 0, -1.4)), 0.35, grey)
    rod(a + Vector((0.4, 0, 0.5)), a + Vector((0.4, 0, -1.4)), 0.35, grey)


BUILDERS = {
    "constellation": (constellation_head, constellation_body),
    "mech": (mech_head, mech_body),
    "eel": (eel_head, eel_body),
}


# --- Rendering --------------------------------------------------------------------------------------


def stage():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 48)):
        if hasattr(scene.eevee, attribute):
            setattr(scene.eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = TILE
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.2
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.006, 0.008, 0.025, 1.0)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 1.0
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 50
    camera.data.clip_end = 5000
    scene.collection.objects.link(camera)
    scene.camera = camera

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (Vector((50, 0, 0)) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (-60, -120, 110), 1.1e6, 120, (1.0, 0.97, 0.92))
    area("Fill", (150, -110, 10), 3e5, 140, (0.75, 0.85, 1.0))
    area("Rim", (50, 140, 80), 1.3e6, 200, (0.55, 0.65, 1.0))
    return scene, camera


def shoot(scene, camera, points, direction, path_out, fill=0.92):
    centre = sum(points, Vector()) / len(points)
    fit(scene, camera, centre, Vector(direction).normalized(), points, fill)
    scene.render.filepath = path_out
    bpy.ops.render.render(write_still=True)


def tile(paths, out, columns):
    images = [bpy.data.images.load(p) for p in paths]
    w, h = images[0].size
    rows = (len(images) + columns - 1) // columns
    sheet = numpy.zeros((rows * h, columns * w, 4), dtype=numpy.float32)
    for index, image in enumerate(images):
        pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(h, w, 4)
        row, column = divmod(index, columns)
        top = (rows - 1 - row) * h
        sheet[top : top + h, column * w : (column + 1) * w] = pixels
    result = bpy.data.images.new("Sheet", columns * w, rows * h, alpha=True)
    result.pixels = sheet.ravel()
    result.filepath_raw = out
    result.file_format = "PNG"
    result.save()


def points_of(objects):
    bpy.context.view_layer.update()
    return [o.matrix_world @ Vector(c) for o in objects if o.type == "MESH" for c in o.bound_box]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    make_head, make_body = BUILDERS[STYLE]
    head = made(make_head)
    body = made(make_body)
    man = made(player)
    scene, camera = stage()
    everything = points_of(head + body + man)
    h = head_frame()
    close = points_of(head) + [h.at(12, 0, FIRST + 4), h.at(12, 0, -FIRST / 2)] + points_of(man)
    base = os.path.splitext(OUT)[0]
    shots = [
        ("front", everything, (-0.85, -0.55, 0.22)),
        ("side", everything, (0.02, -1.0, 0.18)),
        ("head", close, (-0.8, -0.55, 0.15)),
        ("chase", everything, (1.0, 0.2, 0.4)),
    ]
    paths = []
    for name, points, direction in shots:
        p = f"{base}-{name}.png"
        shoot(scene, camera, points, direction, p)
        paths.append(p)
    tile(paths, OUT, 2)


main()
print("Wrote", OUT)
