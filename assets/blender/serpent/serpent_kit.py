# The star serpent's kit of meshes (docs/plans/STAR_SERPENT.md; decision 093). The direction the
# user chose from the concepts (concept_serpent.py, docs/design/concepts/serpent/; 2026-11-10):
# the mech wyrm (B) in the style of the pets and guardians - pearl ceramic, violet plates, a
# guardian's visor with slit eyes under V brows, cyan seams - wearing A's stars: gold specks on
# its flanks and a constellation line down its back. The star egg rides in a cradle on its neck,
# seen from above and from behind, where a chasing player is.
#
# The game builds it on the clients (World/SerpentVisual): the head on the server's greybox head,
# one segment shape copied down the path the head flies, the tail at the end. Built for phones
# (docs/design/BLENDER_ROBLOX.md, sections 3 and 7): one piece per material class, colours baked
# in the vertex colours (glTF COLOR_0; the game leaves plastic white), everything that glows a
# Neon piece of its own, white here and coloured by the game (SerpentLooks):
#   Origin, HeadBody, HeadEyes, HeadGlow, HeadStars - the head about its middle (the server
#        head's centre, Origin): helmet, plates, visor, brows, antennas, fangs, the neck and the
#        egg's cradle; its eyes (their colour tells the hunt's phase); its cyan seams; its gold
#        stars;
#   EggBody, EggGlow - the star egg in the cradle (shown while the egg is inside), about Origin;
#   SegmentOrigin, SegmentBody, SegmentRing, SegmentStar, SegmentStars - a body segment about its
#        centre (SegmentOrigin), at the neck's size: shell, plate and fin; its cyan ring; a gold
#        star on its back (the constellation line runs from star to star); `SegmentStars` is the
#        same star with two on its flanks, worn by every third segment;
#   TailOrigin, TailBody, TailGlow, JetPoint - the tail's thruster about its centre and where its
#        jet comes out.
# The specks (Origin, SegmentOrigin, TailOrigin, JetPoint) are tiny cubes the game measures from;
# insertion into Studio turns the whole kit about Y, which offsets from the specks don't mind.
# Directions: face -Y here (-Z, the look vector, in Roblox), up +Z, the tail towards +Y.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/serpent/serpent_kit.py -- <outdir> [--sheet]
# Writes <outdir>/serpent-kit.glb; with --sheet also <outdir>/serpent-kit.png: the serpent as the
# game assembles it, a check of the look before export.

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SHEET = "--sheet" in ARGS
ARGS = [a for a in ARGS if a != "--sheet"]
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/serpent_kit")

# The body as the game lays it (SerpentLooks.BODY): the neck segment is FIRST thick, the last LAST.
FIRST = 9.0
LAST = 3.0
SPACING = 6.0
SEGMENTS = 18
# Where the kit's groups stand apart (only for looking at the kit; the game measures from specks).
SEGMENT_AT = Vector((30, 0, 0))
TAIL_AT = Vector((50, 0, 0))
# Mesh resolution: smooth-shaded, a 9-stud segment reads round with 20 x 10.
SEGS = 20
RINGS = 10

# Baked colours, sRGB 0..255 (written as they are: Roblox reads COLOR_0 as sRGB numbers).
PEARL = (236, 239, 245)
VIOLET = (112, 84, 210)
DARK = (38, 40, 54)
VISOR = (18, 18, 26)
STEEL = (165, 172, 200)
NIGHT = (44, 38, 120)
SPECK = (240, 205, 120)
WHITE = (255, 255, 255)


# --- Pieces --------------------------------------------------------------------------------------


def paint(obj, rgb):
    mesh = obj.data
    attribute = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0)
    mesh.color_attributes.active_color = attribute
    return obj


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def apply(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def join(name, parts, origin=Vector()):
    """One piece of `parts`, its mesh about `origin` (its object placed there)."""
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = obj.data.name = name
    apply(obj)
    obj.data.transform(Matrix.Translation(-origin))
    obj.location = origin
    return obj


def turn_to(direction):
    return Vector(direction).to_track_quat("Z", "Y").to_euler()


def ball(location, radii, rgb, rotation=(0, 0, 0), segs=SEGS, rings=RINGS):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = radii
    return paint(smooth(obj), rgb)


def speck_star(location, radius, rgb=WHITE):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location)
    return paint(bpy.context.active_object, rgb)


def cone(base, tip, r1, rgb, r2=0.0, vertices=8):
    base, tip = Vector(base), Vector(tip)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=(tip - base).length, location=(base + tip) / 2,
                                    rotation=turn_to(tip - base))
    return paint(smooth(bpy.context.active_object), rgb)


def rod(a, b, radius, rgb, vertices=8):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b - a).length, location=(a + b) / 2,
                                        rotation=turn_to(b - a))
    return paint(smooth(bpy.context.active_object), rgb)


def ring(location, major, minor, rgb, axis, segments=28, sides=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segments, minor_segments=sides,
                                     location=location, rotation=turn_to(axis))
    return paint(smooth(bpy.context.active_object), rgb)


def fin(points, thickness, rgb):
    mesh = bpy.data.meshes.new("Fin")
    mesh.from_pydata([Vector(p) for p in points], [], [list(range(len(points)))])
    obj = bpy.data.objects.new("Fin", mesh)
    bpy.context.scene.collection.objects.link(obj)
    modifier = obj.modifiers.new("Solid", "SOLIDIFY")
    modifier.thickness = thickness
    modifier.offset = 0
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Solid")
    return paint(obj, rgb)


def speck(name, location):
    bpy.ops.mesh.primitive_cube_add(size=0.05, location=location)
    obj = bpy.context.active_object
    obj.name = obj.data.name = name
    paint(obj, WHITE)
    return apply_keep(obj, Vector(location))


def apply_keep(obj, origin):
    apply(obj)
    obj.data.transform(Matrix.Translation(-origin))
    obj.location = origin
    return obj


# --- The head ------------------------------------------------------------------------------------


def H(x, y=0.0, z=0.0):
    """A head point from the concept's frame (x back towards the tail, y across, z up) about the
    head's middle: Blender has the face at -Y, the tail at +Y, the left side at -X."""
    return Vector((y, x - 0.6, z - 0.6))


def tilt_x(angle):
    """A turn about the head's length (Blender Y)."""
    return Matrix.Rotation(angle, 4, "Y").to_euler()


def head():
    body, eyes, glow, stars = [], [], [], []
    # Helmet, crest plate, jaw, a visor band round the front, the violet neck behind.
    body.append(ball(H(0.6, 0, 0.6), (5.0, 6.4, 4.3), PEARL))
    body.append(ball(H(0.4, 0, 2.3), (4.5, 5.8, 2.8), VIOLET))
    body.append(ball(H(-3.3, 0, -2.6), (3.8, 4.4, 1.7), VIOLET, rotation=(math.radians(-7), 0, 0)))
    body.append(ball(H(-4.1, 0, 1.0), (4.3, 2.2, 1.7), VISOR))
    body.append(ball(H(7.4, 0, 0.6), (2.6, 2.6, 2.6), VIOLET, segs=16, rings=8))
    body.append(rod(H(-1.0, 0, 4.0), H(5.0, 0, 5.4), 0.5, DARK))
    glow.append(ring(H(1.6, 0, 0.6), 4.6, 0.25, WHITE, H(1) - H(0)))
    for side in (-1, 1):
        # Slit eyes slanted down to the middle under V brows: the guardians' frown (decision 090).
        eye = ball(H(-6.1, side * 1.8, 1.1), (1.2, 0.3, 0.42), WHITE, segs=12, rings=6)
        eye.rotation_euler = tilt_x(side * 0.35)
        eyes.append(eye)
        body.append(rod(H(-6.3, side * 0.3, 1.9), H(-5.6, side * 3.6, 3.2), 0.45, STEEL))
        # Antenna horns swept back over the cradle, a star on each tip.
        body.append(rod(H(2.0, side * 2.6, 3.6), H(8.0, side * 4.4, 8.2), 0.32, STEEL))
        stars.append(speck_star(H(8.0, side * 4.4, 8.2), 0.7))
        # Fangs from the jaw, a fin at each cheek with a lit edge.
        body.append(cone(H(-7.0, side * 1.7, -2.0), H(-7.2, side * 1.7, 0.0), 0.45, STEEL, vertices=6))
        body.append(fin([H(1.0, side * 4.6, 0.5), H(6.5, side * 8.0, 2.5), H(5.0, side * 4.6, -0.8)], 0.3, VIOLET))
        glow.append(rod(H(1.0, side * 4.6, 0.5), H(6.5, side * 8.0, 2.5), 0.16, WHITE, vertices=6))
    # Two stars on the crest.
    stars.append(speck_star(H(-1.4, 0, 4.6), 0.45))
    stars.append(speck_star(H(1.8, 0, 5.0), 0.45))

    # The cradle on the neck: a stalk, a ring and five prongs round the egg.
    seat = H(8.2, 0, 8.6)
    base = seat + Vector((0, 0, -2.0))
    body.append(rod(H(7.6, 0, 2.8), base, 0.7, DARK))
    body.append(ring(base, 2.2, 0.38, DARK, (0, 0, 1)))
    glow.append(ring(base + Vector((0, 0, 0.05)), 2.25, 0.14, WHITE, (0, 0, 1)))
    for n in range(5):
        a = n / 5 * math.tau + 0.3
        foot = base + Vector((math.cos(a) * 2.2, math.sin(a) * 2.2, 0))
        top = seat + Vector((math.cos(a) * 1.9, math.sin(a) * 1.9, 1.5))
        body.append(cone(foot, top, 0.32, DARK, vertices=6))

    pieces = [
        join("HeadBody", body),
        join("HeadEyes", eyes),
        join("HeadGlow", glow),
        join("HeadStars", stars),
    ]
    pieces += star_egg(seat)
    return pieces


def star_egg(centre, k=1.35):
    """The star egg in the cradle: a pearl capsule with a night-blue cap, gold specks, a gold seam
    and orbit, sparkles round it. It is any rarity from rare up: which one, the hit decides."""
    c = Vector(centre)
    body = [
        ball(c + Vector((0, 0, -0.25)) * 1 + Vector((0, 0, 0)), (1.0 * k, 1.0 * k, 1.1 * k), PEARL),
        ball(c + Vector((0, 0, 0.35 * k)), (0.95 * k, 0.95 * k, 1.0 * k), NIGHT),
    ]
    rng = random.Random(9)
    for _ in range(7):
        a = rng.uniform(0, math.tau)
        z = rng.uniform(0.4, 1.1) * k
        r = 0.95 * k * math.sqrt(max(0.05, 1 - ((z - 0.35 * k) / (1.0 * k)) ** 2))
        body.append(speck_star(c + Vector((math.cos(a) * r, math.sin(a) * r, z)), 0.12 * k, SPECK))
    glow = [
        ring(c + Vector((0, 0, 0.18 * k)), 1.0 * k, 0.08 * k, WHITE, (0, 0, 1)),
        ring(c, 1.45 * k, 0.07 * k, WHITE, (0.35, 0, 1)),
    ]
    for _ in range(6):
        a = rng.uniform(0, math.tau)
        z = rng.uniform(-0.9, 1.6) * k
        glow.append(speck_star(c + Vector((math.cos(a) * 1.75 * k, math.sin(a) * 1.75 * k, z)), 0.15 * k))
    return [join("EggBody", body), join("EggGlow", glow)]


# --- The body ------------------------------------------------------------------------------------


def segment():
    o = SEGMENT_AT
    r = FIRST / 2

    def S(x, y=0.0, z=0.0):
        return o + Vector((y, x, z))

    body = [
        ball(S(0), (r, r * 0.8, r), PEARL),
        ball(S(0, 0, r * 0.3), (r * 0.84, r * 0.72, r * 0.78), VIOLET),
        cone(S(0, 0, r * 0.85), S(r * 0.7, 0, r * 1.7), r * 0.22, STEEL, vertices=4),
    ]
    ring_piece = join("SegmentRing", [ring(S(r * 0.6), r * 0.74, r * 0.06, WHITE, (0, 1, 0))], o)
    # The back star stands on the plate (its top is 1.08 r high), not in it: the constellation
    # line runs through it, over the back.
    back = S(-r * 0.15, 0, r * 1.12)
    star = join("SegmentStar", [speck_star(back, r * 0.15)], o)
    stars = join("SegmentStars", [speck_star(back, r * 0.15)] + [speck_star(S(0, side * r * 0.98), r * 0.12) for side in (-1, 1)], o)
    return [speck("SegmentOrigin", o), join("SegmentBody", body, o), ring_piece, star, stars]


def tail():
    o = TAIL_AT
    r = LAST / 2

    def T(x, y=0.0, z=0.0):
        return o + Vector((y, x, z))

    exit_at = T(r * 3.4)
    body = [
        ball(T(0), (r * 1.1, r * 1.2, r * 1.1), PEARL),
        cone(T(r * 0.6), T(r * 2.4), r * 1.0, DARK, r2=r * 0.85, vertices=16),
        ring(T(r * 2.4), r * 0.85, r * 0.18, DARK, (0, 1, 0), segments=20),
        cone(T(r * 2.4), exit_at, r * 0.85, DARK, r2=r * 0.6, vertices=16),
    ]
    glow = [ring(T(r * 2.4 + 0.02), r * 0.86, r * 0.09, WHITE, (0, 1, 0), segments=20), ball(exit_at, (r * 0.55, 0.15, r * 0.55), WHITE, segs=12, rings=6)]
    return [speck("TailOrigin", o), join("TailBody", body, o), join("TailGlow", glow, o), speck("JetPoint", exit_at)]


def build():
    pieces = [speck("Origin", Vector())] + head() + segment() + tail()
    return pieces


def triangles(piece):
    return sum(len(p.vertices) - 2 for p in piece.data.polygons)


def export(pieces, path):
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    options = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=False, export_materials="NONE")
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    counts = {piece.name: triangles(piece) for piece in pieces}
    print("Wrote", path, len(pieces), "pieces", sum(counts.values()), "triangles", os.path.getsize(path), "bytes")
    print("Triangles:", ", ".join(f"{name} {count}" for name, count in counts.items()))
    worn = sum(counts[n] for n in ("HeadBody", "HeadEyes", "HeadGlow", "HeadStars", "EggBody", "EggGlow", "TailBody", "TailGlow"))
    worn += SEGMENTS * (counts["SegmentBody"] + counts["SegmentRing"] + counts["SegmentStar"])
    print("A whole serpent:", worn, "triangles in", 8 + SEGMENTS * 3, "parts")


# --- The check sheet: the serpent as the game assembles it ----------------------------------------

# SerpentLooks colours the game paints the Neon pieces.
EYE = (255, 200, 60)
CYAN = (80, 220, 255)
GOLD = (255, 214, 110)
LINE = (170, 150, 255)


def srgb_to_linear(rgb):
    return tuple((c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4 for c in rgb)


def baked():
    mat = bpy.data.materials.new("Baked")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.2
    bsdf.inputs["Coat Weight"].default_value = 0.5
    vertex = nodes.new("ShaderNodeVertexColor")
    vertex.layer_name = "Col"
    gamma = nodes.new("ShaderNodeGamma")
    gamma.inputs["Gamma"].default_value = 2.2
    links.new(vertex.outputs["Color"], gamma.inputs["Color"])
    links.new(gamma.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def neon(rgb, strength=6.0):
    mat = bpy.data.materials.new("Neon")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    linear = srgb_to_linear(rgb)
    bsdf.inputs["Base Color"].default_value = (*linear, 1)
    bsdf.inputs["Emission Color"].default_value = (*linear, 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def wear(piece, matrix, mat, scale=(1, 1, 1)):
    copy = piece.copy()
    copy.data = piece.data.copy()
    copy.hide_render = False
    bpy.context.scene.collection.objects.link(copy)
    copy.matrix_world = matrix @ Matrix.Diagonal((*scale, 1))
    copy.data.materials.clear()
    copy.data.materials.append(mat)
    return copy


def spine(s):
    """The path behind the neck, as the head flew it (Blender: forward is -Y)."""
    return Vector((9.0 * math.sin(s / 15.0), s * 0.93, 4.0 * math.sin(s / 20.0 + 0.5)))


def frame(position, back):
    """A frame at `position` whose -Y (the face) looks away from `back` (towards the head)."""
    y = Vector(back).normalized()
    z = Vector((0, 0, 1))
    x = y.cross(z).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = position
    return m


def sheet(pieces, path):
    kit = {piece.name: piece for piece in pieces}
    for piece in pieces:
        piece.hide_render = True
    plastic, cyan, gold, eye = baked(), neon(CYAN), neon(GOLD, 10), neon(EYE, 12)
    neck_back = 7.0
    head_at = frame(spine(0) - Vector((0, neck_back, 0)), (0, 1, 0))
    for name, mat in (("HeadBody", plastic), ("HeadEyes", eye), ("HeadGlow", cyan), ("HeadStars", gold), ("EggBody", plastic), ("EggGlow", gold)):
        wear(kit[name], head_at, mat)
    backs = []
    for i in range(SEGMENTS):
        s = SPACING * (i + 1)
        k = (FIRST + (LAST - FIRST) * i / (SEGMENTS - 1)) / FIRST
        stretch = 0.9 + 0.1 * k
        m = frame(spine(s), spine(s + 0.5) - spine(s - 0.5))
        scale = (k, stretch, k)
        rel = lambda name: m @ (kit["SegmentOrigin"].matrix_world.inverted() @ kit[name].matrix_world)  # noqa: E731
        wear(kit["SegmentBody"], rel("SegmentBody"), plastic, scale)
        wear(kit["SegmentRing"], rel("SegmentRing"), cyan, scale)
        star = "SegmentStars" if i % 3 == 2 else "SegmentStar"
        wear(kit[star], rel(star), gold, scale)
        backs.append(m @ Vector((0, -FIRST / 2 * 0.15 * stretch, FIRST / 2 * 1.12 * k)))
    s = SPACING * (SEGMENTS + 1)
    m = frame(spine(s), spine(s + 0.5) - spine(s - 0.5))
    rel = lambda name: m @ (kit["TailOrigin"].matrix_world.inverted() @ kit[name].matrix_world)  # noqa: E731
    wear(kit["TailBody"], rel("TailBody"), plastic)
    wear(kit["TailGlow"], rel("TailGlow"), cyan)
    # The constellation line (Beams in the game).
    line = neon(LINE, 4)
    for a, b in zip(backs, backs[1:]):
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.12, depth=(b - a).length, location=(a + b) / 2, rotation=turn_to(b - a))
        bpy.context.active_object.data.materials.append(line)
    render(path)


def render(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 48)):
        if hasattr(scene.eevee, attribute):
            setattr(scene.eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = 2400, 1400
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.2
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.006, 0.008, 0.025, 1.0)

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (Vector((0, 50, 0)) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (-120, -60, 110), 1.1e6, 120, (1.0, 0.97, 0.92))
    area("Fill", (-110, 150, 10), 3e5, 140, (0.75, 0.85, 1.0))
    area("Rim", (140, 50, 80), 1.3e6, 200, (0.55, 0.65, 1.0))
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 50
    camera.data.clip_end = 5000
    scene.collection.objects.link(camera)
    scene.camera = camera
    shots = [("front", Vector((0, 40, 0)), Vector((-0.5, -0.85, 0.25)), 150), ("head", Vector((0, 0, 2)), Vector((-0.55, -0.75, 0.3)), 48),
             ("chase", Vector((0, 40, 0)), Vector((0.15, 1.0, 0.45)), 150)]
    base = os.path.splitext(path)[0]
    for name, target, direction, distance in shots:
        camera.location = target + direction.normalized() * distance
        camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{base}-{name}.png"
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    pieces = build()
    export(pieces, os.path.join(OUT_DIR, "serpent-kit.glb"))
    if SHEET:
        sheet(pieces, os.path.join(OUT_DIR, "serpent-kit.png"))


if __name__ == "__main__":
    main()
