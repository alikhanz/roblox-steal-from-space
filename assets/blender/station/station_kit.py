# The central station's kit of meshes (decision 087, docs/plans/STATION.md): the shapes Roblox parts
# can't make. The ring over the dome is eight copies of one segment (a niche in each for a screen)
# with glowing trims along its edges; four struts hold it up; a cone hull under the platform; and the
# capsule kiosks: shell, counter, the badge's ring and the name plate, plus a low round blob for
# whatever needs a squashed sphere (the kiosk's dark inside). One GLB, one node per piece; the game
# gives every copy its place, turn, material and colour (World/StationKit, World/StationModel), as
# with the zones' and terminals' kits (decisions 085, 086). The rest (platform, dome, neon bands,
# engine glow, screens, badge discs) is plain Roblox parts.
#
# Built for slow devices (user, 2026-11-10): one shape serves many copies; few triangles (smooth
# shading does the roundness, not density; budgets below, checked on export); no textures (white
# vertex colours, the part's colour is the colour); UVs only for the Roblox material's texture.
#
# Pieces are modelled at their size in game (studs), so a copy needs no rescaling except the blob;
# keep the sizes in step with Config/StationLooks. Blender +Z is up, the front -Y, which Roblox reads
# as -Z (docs/design/BLENDER_ROBLOX.md, section 1): a ring segment's screen and a kiosk's opening
# face -Y. Roblox centres an imported mesh on its bounds: where a piece's bounds centre sits relative
# to its own reference point is printed, and StationLooks derives the same from the sizes.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/station/station_kit.py -- <outdir> [--sheet] [--preview]
# Writes <outdir>/station-kit.glb; --sheet also <outdir>/station-kit.png (every piece in a row);
# --preview also <outdir>/station-kit-{far,near}.png (the station assembled from the kit, roughly as
# the game will place it, for review).

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SHEET = "--sheet" in ARGS
PREVIEW = "--preview" in ARGS
ARGS = [a for a in ARGS if not a.startswith("--")]
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/station_kit")

# --- Sizes (studs; Config/StationLooks keeps the same) ------------------------------------------

# The ring: eight segments round the dome, each with a flat niche for its screen.
RING_SEGMENTS = 8
RING_OUTER = 94.0
RING_THICKNESS = 3.0
RING_HEIGHT = 14.0
RING_ROUND = 1.0
RING_STEPS = 16  # arc steps per segment
SCREEN_SIZE = (34.0, 11.5)  # the niche: wide, high
SCREEN_BACK = 92.0  # the niche's flat back, from the ring's centre
TRIM_SIZE = 0.6  # the glowing trims' square section, on the outer edges
# A strut: from the platform's edge up to the ring's underside.
PYLON_LENGTH = 93.5
PYLON_RADIUS = (1.4, 1.0)  # foot, top
# The hull: a cone under the platform, engine pods under its tip.
HULL_TOP_RADIUS = 61.0
HULL_BOTTOM_RADIUS = 16.0
HULL_DEPTH = 40.0
ENGINE_COUNT = 8
ENGINE_RADIUS = 2.2
ENGINE_DEPTH = 3.0
# A kiosk: an egg shell cut open at the front, standing on its base's top.
SHELL_RADIUS = 4.4
SHELL_STRETCH = 1.5
COUNTER_SIZE = (6.6, 2.0, 2.6)
BADGE_RADIUS = 2.6
BADGE_TUBE = 0.28
PLATE_SIZE = (10.0, 0.5, 2.0)

# Triangle budgets per piece (docs/plans/STATION.md): the export fails loudly past them.
BUDGET = {
    "RingSegment": 1500,
    "RingTrim": 200,
    "Pylon": 300,
    "Hull": 4000,
    "KioskShell": 2000,
    "KioskCounter": 500,
    "Blob": 500,
    "BadgeRing": 400,
    "LabelPlate": 300,
}


def new_object(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def white(obj):
    attribute = obj.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color_srgb = (1.0, 1.0, 1.0, 1.0)
    obj.data.color_attributes.active_color = attribute


def finish(obj, smooth_angle=40):
    """Applies transforms and modifiers, shades smooth by angle (round where round, sharp where
    flat), white vertex colours. Keeps the origin where the piece was built (its reference point)."""
    select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    white(obj)
    return obj


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def from_bmesh(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return new_object(name, mesh)


def cut(target, cutter):
    """Boolean difference; the cutter is removed."""
    mod = target.modifiers.new("Cut", "BOOLEAN")
    mod.object = cutter
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    select_only(target)
    bpy.ops.object.modifier_apply(modifier="Cut")
    bpy.data.objects.remove(cutter)


# --- Pieces ---------------------------------------------------------------------------------------


def rounded_rect(width, height, radius, corner_steps=3):
    """A rectangle's outline with rounded corners, centred, as (u, v) points anticlockwise."""
    points = []
    hw, hh = width / 2 - radius, height / 2 - radius
    for cx, cy, start in ((hw, hh, 0), (-hw, hh, 90), (-hw, -hh, 180), (hw, -hh, 270)):
        for i in range(corner_steps + 1):
            a = math.radians(start + 90 * i / corner_steps)
            points.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius))
    return points


def sweep(name, profile, centre_radius, angle, steps):
    """`profile` (u radial, v up) swept round Z through `angle` centred on -Y, capped at both ends."""
    bm = bmesh.new()
    rings = []
    for s in range(steps + 1):
        a = -math.pi / 2 - angle / 2 + angle * s / steps
        direction = Vector((math.cos(a), math.sin(a), 0))
        rings.append([bm.verts.new(direction * (centre_radius + u) + Vector((0, 0, v))) for u, v in profile])
    n = len(profile)
    for s in range(steps):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((rings[s][i], rings[s][j], rings[s + 1][j], rings[s + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return from_bmesh(name, bm)


def ring_segment():
    """One eighth of the ring's band, its reference point the ring's centre (at the band's middle
    height), its screen niche facing -Y."""
    angle = 2 * math.pi / RING_SEGMENTS
    profile = rounded_rect(RING_THICKNESS, RING_HEIGHT, RING_ROUND)
    obj = sweep("RingSegment", profile, RING_OUTER - RING_THICKNESS / 2, angle, RING_STEPS)
    # The niche: a box whose back face is the flat plane SCREEN_BACK from the centre.
    w, h = SCREEN_SIZE
    depth = 10.0
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -(SCREEN_BACK + depth / 2), 0))
    cutter = bpy.context.active_object
    cutter.scale = (w, depth, h)
    cut(obj, cutter)
    return finish(obj, 35)


def ring_trim():
    """A glowing trim along one outer edge of a segment (top or bottom: the same shape), its
    reference point the ring's centre at the trim's height."""
    angle = 2 * math.pi / RING_SEGMENTS
    profile = [(TRIM_SIZE / 2, TRIM_SIZE / 2), (-TRIM_SIZE / 2, TRIM_SIZE / 2), (-TRIM_SIZE / 2, -TRIM_SIZE / 2), (TRIM_SIZE / 2, -TRIM_SIZE / 2)]
    obj = sweep("RingTrim", profile, RING_OUTER - TRIM_SIZE * 0.3, angle, RING_STEPS)
    return finish(obj, 60)


def pylon():
    """A strut along +Z, tapering from its foot; reference point the foot's centre."""
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=PYLON_RADIUS[0], radius2=PYLON_RADIUS[1], depth=PYLON_LENGTH, location=(0, 0, PYLON_LENGTH / 2))
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Pylon"
    return finish(obj, 50)


def hull():
    """The cone under the platform, its reference point the centre of its top (the platform's
    underside); engine pods round the tip."""
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=HULL_BOTTOM_RADIUS, radius2=HULL_TOP_RADIUS, depth=HULL_DEPTH, location=(0, 0, -HULL_DEPTH / 2))
    cone = bpy.context.active_object
    parts = [cone]
    for k in range(ENGINE_COUNT):
        a = k / ENGINE_COUNT * math.tau
        at = Vector((math.cos(a), math.sin(a), 0)) * HULL_BOTTOM_RADIUS * 0.65 + Vector((0, 0, -HULL_DEPTH - ENGINE_DEPTH / 2 + 0.5))
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=ENGINE_RADIUS, depth=ENGINE_DEPTH, location=at)
        parts.append(bpy.context.active_object)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = cone
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Hull"
    return finish(obj, 30)


def kiosk_shell():
    """The capsule: an egg cut flat at its foot and open at the front (-Y), two antennae on top.
    Reference point: the centre of its foot."""
    # The egg, its bottom cut 1.1 above the lowest point so it stands flat.
    lift = SHELL_RADIUS * SHELL_STRETCH - 1.1
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=16, radius=SHELL_RADIUS, location=(0, 0, lift))
    obj = bpy.context.active_object
    obj.scale = (1, 1, SHELL_STRETCH)
    select_only(obj)
    bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    result = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(obj.data)
    bm.free()
    # The opening: a rounded box through the front, from the counter's height up.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -SHELL_RADIUS, lift - 0.6))
    cutter = bpy.context.active_object
    cutter.scale = (6.4, SHELL_RADIUS * 1.4, 7.4)
    select_only(cutter)
    bpy.ops.object.transform_apply(scale=True)
    bevel = cutter.modifiers.new("Round", "BEVEL")
    bevel.width, bevel.segments, bevel.limit_method = 1.4, 3, "NONE"
    select_only(cutter)
    bpy.ops.object.modifier_apply(modifier="Round")
    # Hollow it: the shell is a skin the inside blob shows through.
    solidify = obj.modifiers.new("Skin", "SOLIDIFY")
    solidify.thickness = 0.35
    solidify.offset = -1
    select_only(obj)
    bpy.ops.object.modifier_apply(modifier="Skin")
    cut(obj, cutter)
    # Antennae: thin stalks leaning out (their glowing tips are Roblox balls).
    top = lift + SHELL_RADIUS * SHELL_STRETCH
    parts = [obj]
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.12, depth=2.0, location=(side * 1.35, 0, top + 0.45), rotation=(0, side * 0.3, 0))
        parts.append(bpy.context.active_object)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = obj.data.name = "KioskShell"
    return finish(obj, 45)


def rounded_box(name, size, radius, segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    obj.name = obj.data.name = name
    obj.scale = size
    select_only(obj)
    bpy.ops.object.transform_apply(scale=True)
    bevel = obj.modifiers.new("Round", "BEVEL")
    bevel.width = min(radius, min(size) / 2 - 0.01)
    bevel.segments = segments
    bevel.limit_method = "NONE"
    return finish(obj, 40)


def label_plate():
    """A pill-shaped plate for a kiosk's name: round ends, slightly rounded faces."""
    w, d, h = PLATE_SIZE
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(w, d, h), verts=bm.verts)
    # Round the four edges along Y into the pill's ends.
    ends = [e for e in bm.edges if abs((e.verts[0].co - e.verts[1].co).normalized().y) > 0.99]
    bmesh.ops.bevel(bm, geom=ends, offset=h / 2 - 0.01, segments=6, affect="EDGES", profile=0.5)
    obj = from_bmesh("LabelPlate", bm)
    bevel = obj.modifiers.new("Soft", "BEVEL")
    bevel.width, bevel.segments, bevel.limit_method = 0.1, 1, "ANGLE"
    return finish(obj, 40)


def blob():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0)
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Blob"
    return finish(obj, 180)


def badge_ring():
    bpy.ops.mesh.primitive_torus_add(major_radius=BADGE_RADIUS, minor_radius=BADGE_TUBE, major_segments=32, minor_segments=6, rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.active_object
    obj.name = obj.data.name = "BadgeRing"
    return finish(obj, 180)


def uv(obj):
    """UVs for the Roblox material's texture: a smart projection at the mesh's own scale."""
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


# Piece names are the game's (World/StationKit): keep them in step.
def build():
    pieces = [
        ring_segment(),
        ring_trim(),
        pylon(),
        hull(),
        kiosk_shell(),
        rounded_box("KioskCounter", COUNTER_SIZE, 0.9),
        blob(),
        badge_ring(),
        label_plate(),
    ]
    over = []
    for piece in pieces:
        uv(piece)
        low, high = bounds(piece)
        centre = (low + high) / 2
        count = triangles(piece)
        print(f"{piece.name}: {count} tris, size {tuple(round(d, 2) for d in high - low)}, bounds centre from reference {tuple(round(c, 2) for c in centre)}")
        if count > BUDGET[piece.name]:
            over.append(f"{piece.name} {count} > {BUDGET[piece.name]}")
    if over:
        raise SystemExit("Over the triangle budget: " + ", ".join(over))
    return pieces


def bounds(obj):
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return low, high


def export(pieces, path):
    for piece in pieces:
        piece.select_set(False)
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    options = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=True, export_materials="NONE")
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    total = sum(triangles(p) for p in pieces)
    print("Wrote", path, len(pieces), "pieces", total, "triangles", os.path.getsize(path), "bytes")


# --- Review pictures (not exported) --------------------------------------------------------------


def material(name, colour, roughness=0.4, metallic=0.0, emission=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*colour, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
    return mat


def copy(piece, mat, matrix, scale=(1, 1, 1)):
    obj = bpy.data.objects.new(piece.name + "Copy", piece.data.copy())
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.matrix_world = matrix @ Matrix.Diagonal((*scale, 1))
    bpy.context.scene.collection.objects.link(obj)
    return obj


def prim(kind, mat, location, size, rotation=(0, 0, 0)):
    if kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=size[0], depth=size[1], location=location, rotation=rotation)
    elif kind == "ball":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=size[0], location=location)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
        bpy.context.active_object.scale = size
    obj = bpy.context.active_object
    obj.data.materials.append(mat)
    return obj


def preview(pieces, out_dir):
    """The station assembled from the kit, roughly as the game will place it: to judge the shapes
    and proportions, not the final colours."""
    kit = {p.name: p for p in pieces}
    for p in pieces:
        p.hide_render = True
    steel = material("Steel", (0.30, 0.33, 0.42), 0.35, 0.6)
    steel_light = material("SteelLight", (0.72, 0.75, 0.82), 0.3, 0.5)
    pearl = material("Pearl", (0.84, 0.86, 0.92), 0.2)
    navy = material("Navy", (0.035, 0.05, 0.12), 0.25)
    cyan = material("Cyan", (0.25, 0.75, 1.0), emission=4.0)
    screen = material("Screen", (0.05, 0.12, 0.3), 0.1, emission=0.6)
    floor = material("Floor", (0.18, 0.2, 0.27), 0.6)
    dome = material("Dome", (0.35, 0.85, 1.0), emission=0.4, alpha=0.08)
    accents = [(1.0, 0.45, 0.12), (0.6, 0.38, 1.0), (0.15, 0.9, 0.7), (1.0, 0.32, 0.68), (1.0, 0.72, 0.18)]

    dome_z = math.sqrt(90**2 - 62**2)
    prim("cyl", floor, (0, 0, -2), (60, 4))
    prim("cyl", cyan, (0, 0, -1.08), (62, 2))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=90, location=(0, 0, dome_z))
    bpy.context.active_object.data.materials.append(dome)
    # Hull and its bands (Roblox discs poking out of the cone).
    copy(kit["Hull"], steel, Matrix.Translation((0, 0, -4)))
    for frac in (0.25, 0.6):
        r = HULL_TOP_RADIUS - (HULL_TOP_RADIUS - HULL_BOTTOM_RADIUS) * frac
        prim("cyl", cyan, (0, 0, -4 - HULL_DEPTH * frac), (r + 0.3, 0.8))
    for k in range(ENGINE_COUNT):
        a = k / ENGINE_COUNT * math.tau
        at = Vector((math.cos(a), math.sin(a), 0)) * HULL_BOTTOM_RADIUS * 0.65 + Vector((0, 0, -4 - HULL_DEPTH - ENGINE_DEPTH + 0.4))
        prim("cyl", material(f"Engine{k}", (1.0, 0.5, 0.15), emission=5.0), at, (1.6, 0.3))
    # The ring: eight segments, each turned to face its island; trims; screens in the niches.
    ring_z = 92.0
    for k in range(RING_SEGMENTS):
        a = k / RING_SEGMENTS * math.tau
        turn = Matrix.Rotation(a + math.pi / 2, 4, "Z")  # -Y turned to face angle a
        copy(kit["RingSegment"], steel, Matrix.Translation((0, 0, ring_z)) @ turn)
        for dz in (RING_HEIGHT / 2 - TRIM_SIZE / 2, -RING_HEIGHT / 2 + TRIM_SIZE / 2):
            copy(kit["RingTrim"], cyan, Matrix.Translation((0, 0, ring_z + dz)) @ turn)
        out = Vector((math.cos(a), math.sin(a), 0))
        prim("box", screen, out * (SCREEN_BACK + 0.15) + Vector((0, 0, ring_z)), (SCREEN_SIZE[0] - 0.6, 0.2, SCREEN_SIZE[1] - 0.6), (0, 0, a + math.pi / 2))
    # Struts from the platform's edge to the ring's underside.
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2 + math.pi / 8
        out = Vector((math.cos(a), math.sin(a), 0))
        foot = out * 61 + Vector((0, 0, -3))
        tip = out * (RING_OUTER - 1.5) + Vector((0, 0, ring_z - RING_HEIGHT / 2))
        rot = (tip - foot).to_track_quat("Z", "Y").to_matrix().to_4x4()
        copy(kit["Pylon"], steel_light, Matrix.Translation(foot) @ rot, (1, 1, (tip - foot).length / PYLON_LENGTH))
    # Kiosks and the coin board in a circle, facing out.
    for k in range(5):
        a = k / 5 * math.tau
        out = Vector((math.cos(a), math.sin(a), 0))
        at = out * 36
        face = Matrix.Translation(at) @ Matrix.Rotation(a + math.pi / 2, 4, "Z")  # -Y faces out
        colour = accents[k]
        glow = material(f"Glow{k}", colour, emission=4.0)
        prim("cyl", navy, at + Vector((0, 0, 0.35)), (5.2, 0.7))
        prim("cyl", glow, at + Vector((0, 0, 0.15)), (5.45, 0.3))
        if k < 4:
            copy(kit["KioskShell"], pearl, face @ Matrix.Translation((0, 0, 0.7)))
            copy(kit["Blob"], navy, face @ Matrix.Translation((0, 0.6, 6.2)), (4.0, 2.5, 5.8))
            prim("cyl", glow, at + Vector((0, 0, 2.3)), (4.5, 0.6))
            copy(kit["KioskCounter"], pearl, face @ Matrix.Translation((0, -3.4, 2.0)))
            top = 0.7 + SHELL_RADIUS * SHELL_STRETCH * 2 - 1.1
        else:
            copy(kit["KioskCounter"], pearl, face @ Matrix.Translation((0, 0, 2.0)))
            prim("box", screen, at + Vector((0, 0, 8.5)), (10, 0.4, 10), (0, 0, a + math.pi / 2))
            top = 13.5
        badge = face @ Matrix.Translation((0, -0.4, top + 6.0))
        copy(kit["BadgeRing"], glow, badge)
        prim("cyl", navy, (badge @ Vector((0, 0.2, 0))), (2.45, 0.2), (math.pi / 2, 0, a + math.pi / 2))
        copy(kit["LabelPlate"], navy, badge @ Matrix.Translation((0, 0, -3.6)))
        copy(kit["LabelPlate"], glow, badge @ Matrix.Translation((0, 0.12, -3.6)), (1.05, 1.0, 1.15))

    world = bpy.data.worlds.new("Space")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.01, 0.012, 0.03, 1)
    scene = bpy.context.scene
    scene.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy, sun.color = 2.6, (1.0, 0.93, 0.84)
    sun_obj = new_object("Sun", sun)
    sun_obj.rotation_euler = Vector((-0.5, 0.3, -0.8)).to_track_quat("-Z", "Y").to_euler()
    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy, fill.color = 0.6, (0.55, 0.5, 0.95)
    fill_obj = new_object("Fill", fill)
    fill_obj.rotation_euler = Vector((0.6, -0.5, 0.3)).to_track_quat("-Z", "Y").to_euler()
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    camera_data = bpy.data.cameras.new("Cam")
    camera_data.clip_end = 3000
    camera = new_object("Cam", camera_data)
    scene.camera = camera
    for name, eye, at, lens in (("far", (355, 4, 17), (0, 0, 40), 19), ("near", (64, -16, 13), (0, 4, 30), 16)):
        camera_data.lens = lens
        camera.location = eye
        camera.rotation_euler = (Vector(at) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, f"station-kit-{name}.png")
        bpy.ops.render.render(write_still=True)
        print("Wrote", scene.render.filepath)


def sheet(pieces, path):
    """Every piece in a row, lit: a check of the shapes, not the game's look. Big pieces are shown
    shrunk to fit (their label says so)."""
    grey = material("Grey", (0.45, 0.48, 0.55), 0.4, 0.4)
    scene = bpy.context.scene
    copies = []
    x = 0.0
    for piece in pieces:
        low, high = bounds(piece)
        size = max(high - low)
        k = 8.0 / size if size > 8.0 else 1.0
        centre = (low + high) / 2
        obj = copy(piece, grey, Matrix.Translation((x, 0, 0)) @ Matrix.Diagonal((k, k, k, 1)) @ Matrix.Translation(-centre))
        copies.append(obj)
        x += 10.0
    for piece in pieces:
        piece.hide_render = True
    span = x - 10.0
    world = bpy.data.worlds.new("Sheet")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.04, 1)
    scene.world = world
    data = bpy.data.lights.new("Key", "SUN")
    data.energy = 3.5
    light = new_object("Key", data)
    light.rotation_euler = Vector((0.3, 0.8, -0.6)).to_track_quat("-Z", "Y").to_euler()
    camera_data = bpy.data.cameras.new("SheetCam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = span + 10.0
    camera = new_object("SheetCam", camera_data)
    camera.location = (span / 2, -40, 14)
    camera.rotation_euler = (Vector((span / 2, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 400
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Wrote", path)
    for obj in copies:
        bpy.data.objects.remove(obj)
    for piece in pieces:
        piece.hide_render = False


bpy.ops.wm.read_factory_settings(use_empty=True)
os.makedirs(OUT_DIR, exist_ok=True)
kit = build()
export(kit, os.path.join(OUT_DIR, "station-kit.glb"))
if SHEET:
    sheet(kit, os.path.join(OUT_DIR, "station-kit.png"))
if PREVIEW:
    preview(kit, OUT_DIR)
