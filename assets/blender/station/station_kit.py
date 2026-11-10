# The central station's kit of meshes (decision 087, docs/plans/STATION.md): the shapes Roblox parts
# can't make. The ring over the dome is eight copies of one segment (a niche in each for a screen)
# with one glowing trim round both its edges; four struts hold it up; a cone hull under the platform
# with one glowing piece for its bands and engine nozzles; and the capsule kiosk in three pieces by
# material: pearl (shell, antennae, counter), dark (base, inside) and glow (rings, strip, tips, the
# badge's ring, the plate's frame), plus the name plate. One GLB, one node per piece; the game gives
# every copy its place, turn, material and colour (World/StationKit, World/StationModel,
# World/KioskModel), as with the zones' and terminals' kits (decisions 085, 086). The rest
# (platform, dome, screens, the badge's disc, the hologram) is plain Roblox parts.
#
# Built for slow devices (user, 2026-11-10; the pets' lessons, docs/design/BLENDER_ROBLOX.md): one
# shape serves many copies; parts joined by material, one MeshPart a material (a kiosk is three
# meshes, not fourteen parts); few triangles (smooth shading does the roundness, not density;
# budgets below, checked on export); no textures (white vertex colours, the part's colour is the
# colour); UVs only for the Roblox material's texture. Points the game needs (the kiosk's prompt)
# are attachments made in code, not marker meshes.
#
# Pieces are modelled at their size in game (studs), around a reference point that is easy to place
# (the ring's centre, a strut's foot, the hull's top, a kiosk's spot on the floor); keep the sizes in
# step with Config/StationShape and Config/StationLooks (a test reads this file). Blender +Z is up,
# the front -Y, which Roblox reads as -Z (docs/design/BLENDER_ROBLOX.md, section 1): a ring
# segment's screen and a kiosk's opening face -Y. Roblox centres an imported mesh on its bounds:
# where a piece's bounds centre sits relative to its reference point is printed, for
# World/StationKit's OFFSETS.
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

# --- Sizes (studs; Config/StationShape and StationLooks keep the same) ---------------------------

# The ring: eight segments round the dome, each with a flat niche for its screen.
RING_SEGMENTS = 8
RING_OUTER = 94.0
RING_THICKNESS = 3.0
RING_HEIGHT = 14.0
RING_ROUND = 1.0
RING_STEPS = 16  # arc steps per segment (the trim: as many round the whole ring)
SCREEN_SIZE = (34.0, 11.5)  # the niche: wide, high
SCREEN_BACK = 92.0  # the niche's flat back, from the ring's centre
TRIM_SIZE = 0.6  # the glowing trims' square section, on the outer edges
# A strut: from the platform's edge up to the ring's underside (stretched to length in game).
PYLON_LENGTH = 93.5
PYLON_RADIUS = (1.4, 1.0)  # foot, top
# The hull: a cone under the platform, engine pods under its tip.
HULL_TOP_RADIUS = 61.0
HULL_BOTTOM_RADIUS = 16.0
HULL_DEPTH = 40.0
HULL_BANDS = (0.25, 0.6)  # glowing bands at these fractions of the depth
ENGINE_COUNT = 8
ENGINE_RADIUS = 2.2
ENGINE_DEPTH = 3.0
NOZZLE_RADIUS = 1.6
# A kiosk, from its spot on the floor: a base, the egg shell on it cut open at the front.
KIOSK_BASE_RADIUS = 5.2
KIOSK_BASE_HEIGHT = 0.7
KIOSK_GLOW_RADIUS = 5.45
SHELL_RADIUS = 4.4
SHELL_STRETCH = 1.5
SHELL_SINK = 1.1  # how much of the egg's bottom is cut off so it stands flat
SHELL_CENTRE = KIOSK_BASE_HEIGHT + SHELL_RADIUS * SHELL_STRETCH - SHELL_SINK
SHELL_TOP = SHELL_CENTRE + SHELL_RADIUS * SHELL_STRETCH
INSIDE_CENTRE = (0.0, 0.6, SHELL_CENTRE)  # the dark inside, a squashed sphere behind the opening
INSIDE_RADII = (4.0, 2.5, 5.8)
BAND_HEIGHT = 2.3
COUNTER_CENTRE = (0.0, -3.4, 2.0)
COUNTER_SIZE = (6.6, 2.0, 2.6)
TIP_RADIUS = 0.38
BADGE_CENTRE = (0.0, -0.4, 18.8)
BADGE_RADIUS = 2.6
BADGE_TUBE = 0.28
PLATE_CENTRE = (0.0, -0.4, 15.2)
PLATE_SIZE = (10.0, 0.5, 2.0)
PLATE_FRAME_SCALE = (1.05, 1.0, 1.15)
PLATE_FRAME_BACK = 0.12

# Triangle budgets per piece (docs/plans/STATION.md): the export fails loudly past them.
BUDGET = {
    "RingSegment": 1500,
    "RingGlow": 1200,
    "Pylon": 300,
    "Hull": 4000,
    "HullGlow": 1200,
    "KioskPearl": 2600,
    "KioskDark": 900,
    "KioskGlow": 1500,
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


def solid(obj):
    """Applies an object's transforms and modifiers: its mesh in the reference point's frame."""
    select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def finish(obj, smooth_angle=40):
    """Makes `obj` a piece: solid, shaded smooth by angle (round where round, sharp where flat),
    white vertex colours."""
    solid(obj)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    white(obj)
    return obj


def merge(name, objs, smooth_angle=40):
    """One piece of several shapes of the same material."""
    for obj in objs:
        solid(obj)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = obj.data.name = name
    return finish(obj, smooth_angle)


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


def active():
    return bpy.context.active_object


# --- Shapes ----------------------------------------------------------------------------------------


def rounded_rect(width, height, radius, corner_steps=3):
    """A rectangle's outline with rounded corners, centred, as (u, v) points anticlockwise."""
    points = []
    hw, hh = width / 2 - radius, height / 2 - radius
    for cx, cy, start in ((hw, hh, 0), (-hw, hh, 90), (-hw, -hh, 180), (hw, -hh, 270)):
        for i in range(corner_steps + 1):
            a = math.radians(start + 90 * i / corner_steps)
            points.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius))
    return points


def square(size):
    h = size / 2
    return [(h, h), (-h, h), (-h, -h), (h, -h)]


def sweep(name, profile, centre_radius, angle, steps, lift=0.0):
    """`profile` (u radial, v up) swept round Z through `angle` centred on -Y, `lift` up; capped at
    both ends, or closed into a loop for a full turn."""
    closed = abs(angle - 2 * math.pi) < 1e-6
    bm = bmesh.new()
    rings = []
    for s in range(steps if closed else steps + 1):
        a = -math.pi / 2 - angle / 2 + angle * s / steps
        direction = Vector((math.cos(a), math.sin(a), 0))
        rings.append([bm.verts.new(direction * (centre_radius + u) + Vector((0, 0, v + lift))) for u, v in profile])
    n = len(profile)
    for s in range(len(rings) if closed else steps):
        here, there = rings[s], rings[(s + 1) % len(rings)]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((here[i], here[j], there[j], there[i]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return from_bmesh(name, bm)


def cylinder(radius, depth, location, vertices=32, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    return active()


def torus(major, minor, location, rotation=(0, 0, 0), major_segments=32, minor_segments=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=location, rotation=rotation,
                                     major_segments=major_segments, minor_segments=minor_segments)
    return active()


def rounded_box(size, radius, location=(0, 0, 0), segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = active()
    obj.scale = size
    bevel = obj.modifiers.new("Round", "BEVEL")
    bevel.width = min(radius, min(size) / 2 - 0.01)
    bevel.segments = segments
    bevel.limit_method = "NONE"
    # The bevel works in the mesh's own (unscaled) size: apply the scale first.
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def pill_plate(size, location=(0, 0, 0), scale=(1, 1, 1)):
    """A pill-shaped plate (round ends, softened faces) in the XZ plane."""
    w, d, h = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(w, d, h), verts=bm.verts)
    # Round the four edges along Y into the pill's ends.
    ends = [e for e in bm.edges if abs((e.verts[0].co - e.verts[1].co).normalized().y) > 0.99]
    bmesh.ops.bevel(bm, geom=ends, offset=h / 2 - 0.01, segments=6, affect="EDGES", profile=0.5)
    obj = from_bmesh("Plate", bm)
    bevel = obj.modifiers.new("Soft", "BEVEL")
    bevel.width, bevel.segments, bevel.limit_method = 0.1, 1, "ANGLE"
    obj.location = location
    obj.scale = scale
    return obj


def shell_radius_at(z):
    """The egg shell's radius at height `z` above the kiosk's floor spot."""
    dz = (z - SHELL_CENTRE) / SHELL_STRETCH
    return math.sqrt(max(0.0, SHELL_RADIUS**2 - dz**2))


# --- Pieces ---------------------------------------------------------------------------------------


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
    cutter = active()
    cutter.scale = (w, depth, h)
    cut(obj, cutter)
    return finish(obj, 35)


def ring_glow():
    """The glowing trims along the ring's top and bottom outer edges, all the way round: one piece
    for the whole ring, its reference point the ring's centre."""
    steps = RING_STEPS * RING_SEGMENTS // 2
    lift = RING_HEIGHT / 2 - TRIM_SIZE / 2
    radius = RING_OUTER - TRIM_SIZE * 0.3
    parts = [sweep("Trim", square(TRIM_SIZE), radius, 2 * math.pi, steps, side * lift) for side in (1, -1)]
    return merge("RingGlow", parts, 60)


def pylon():
    """A strut along +Z, tapering from its foot; reference point the foot's centre."""
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=PYLON_RADIUS[0], radius2=PYLON_RADIUS[1], depth=PYLON_LENGTH, location=(0, 0, PYLON_LENGTH / 2))
    obj = active()
    obj.name = obj.data.name = "Pylon"
    return finish(obj, 50)


def engine_at(k):
    a = k / ENGINE_COUNT * math.tau
    return Vector((math.cos(a), math.sin(a), 0)) * HULL_BOTTOM_RADIUS * 0.65


def hull():
    """The cone under the platform, its reference point the centre of its top (the platform's
    underside); engine pods round the tip."""
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=HULL_BOTTOM_RADIUS, radius2=HULL_TOP_RADIUS, depth=HULL_DEPTH, location=(0, 0, -HULL_DEPTH / 2))
    parts = [active()]
    for k in range(ENGINE_COUNT):
        parts.append(cylinder(ENGINE_RADIUS, ENGINE_DEPTH, engine_at(k) + Vector((0, 0, -HULL_DEPTH - ENGINE_DEPTH / 2 + 0.5)), 12))
    return merge("Hull", parts, 30)


def hull_glow():
    """The hull's glowing bands round the cone and its engines' nozzles: one piece, reference point
    the hull's top."""
    parts = []
    for share in HULL_BANDS:
        depth = HULL_DEPTH * share
        radius = HULL_TOP_RADIUS + (HULL_BOTTOM_RADIUS - HULL_TOP_RADIUS) * share
        band = torus(radius + 0.1, 0.4, (0, 0, -depth), major_segments=48, minor_segments=4)
        parts.append(band)
    nozzle_z = -HULL_DEPTH - ENGINE_DEPTH + 0.5 - 0.15
    for k in range(ENGINE_COUNT):
        parts.append(cylinder(NOZZLE_RADIUS, 0.3, engine_at(k) + Vector((0, 0, nozzle_z)), 12))
    return merge("HullGlow", parts, 60)


def kiosk_pearl():
    """The kiosk's pearl: the egg shell cut flat at its foot and open at the front (-Y), its two
    antennae, and the counter. Reference point: the kiosk's spot on the floor."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=16, radius=SHELL_RADIUS, location=(0, 0, SHELL_CENTRE))
    shell = active()
    shell.scale = (1, 1, SHELL_STRETCH)
    solid(shell)
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    result = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, KIOSK_BASE_HEIGHT), plane_no=(0, 0, 1), clear_inner=True)
    edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(shell.data)
    bm.free()
    # The opening: a rounded box through the front, from the counter's height up.
    cutter = rounded_box((6.4, SHELL_RADIUS * 1.4, 7.4), 1.4, (0, -SHELL_RADIUS, SHELL_CENTRE - 0.6))
    solid(cutter)
    # Hollow: the shell is a skin the dark inside shows through.
    skin = shell.modifiers.new("Skin", "SOLIDIFY")
    skin.thickness = 0.35
    skin.offset = -1
    solid(shell)
    cut(shell, cutter)
    parts = [shell]
    for side in (-1, 1):
        parts.append(cylinder(0.12, 2.0, (side * 1.35, 0, SHELL_TOP - 0.3 + 0.45), 6, (0, side * 0.3, 0)))
    parts.append(rounded_box(COUNTER_SIZE, 0.9, COUNTER_CENTRE))
    return merge("KioskPearl", parts, 45)


def tip_centres():
    """The antennae's ends, where their glowing tips sit."""
    centres = []
    for side in (-1, 1):
        base = Vector((side * 1.35, 0, SHELL_TOP - 0.3 + 0.45))
        centres.append(base + Vector((math.sin(side * 0.3), 0, math.cos(0.3))))
    return centres


def kiosk_dark():
    """The kiosk's dark: its round base and the inside behind the opening. Reference point: the
    kiosk's spot on the floor."""
    base = cylinder(KIOSK_BASE_RADIUS, KIOSK_BASE_HEIGHT, (0, 0, KIOSK_BASE_HEIGHT / 2), 32)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=INSIDE_CENTRE)
    inside = active()
    inside.scale = INSIDE_RADII
    return merge("KioskDark", [base, inside], 50)


def kiosk_glow():
    """Everything on a kiosk that glows in its colour: the ring under the base, the band round the
    shell, the counter's strip, the antennae's tips, the badge's ring and the plate's frame.
    Reference point: the kiosk's spot on the floor."""
    parts = [cylinder(KIOSK_GLOW_RADIUS, 0.3, (0, 0, 0.15), 32)]
    parts.append(torus(shell_radius_at(BAND_HEIGHT) + 0.05, 0.3, (0, 0, BAND_HEIGHT), major_segments=28, minor_segments=4))
    cx, cy, cz = COUNTER_CENTRE
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy - COUNTER_SIZE[1] / 2 - 0.05, cz + 0.35))
    strip = active()
    strip.scale = (5.6, 0.1, 0.35)
    parts.append(strip)
    for centre in tip_centres():
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=TIP_RADIUS, location=centre)
        parts.append(active())
    parts.append(torus(BADGE_RADIUS, BADGE_TUBE, BADGE_CENTRE, (math.pi / 2, 0, 0)))
    px, py, pz = PLATE_CENTRE
    parts.append(pill_plate(PLATE_SIZE, (px, py + PLATE_FRAME_BACK, pz), PLATE_FRAME_SCALE))
    return merge("KioskGlow", parts, 50)


def label_plate():
    """The plate a kiosk's name is drawn on (the game puts it at PLATE_CENTRE). Reference point:
    its centre."""
    obj = pill_plate(PLATE_SIZE)
    obj.name = obj.data.name = "LabelPlate"
    return finish(obj, 40)


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
        ring_glow(),
        pylon(),
        hull(),
        hull_glow(),
        kiosk_pearl(),
        kiosk_dark(),
        kiosk_glow(),
        label_plate(),
    ]
    over = []
    for piece in pieces:
        uv(piece)
        low, high = bounds(piece)
        centre = (low + high) / 2
        roblox = (-centre.x, centre.z, centre.y)
        count = triangles(piece)
        print(f"{piece.name}: {count} tris, size {tuple(round(d, 2) for d in high - low)}, bounds centre from reference (Roblox) {tuple(round(c, 2) for c in roblox)}")
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
    else:
        bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
        active().scale = size
    obj = active()
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
    active().data.materials.append(dome)
    copy(kit["Hull"], steel, Matrix.Translation((0, 0, -4)))
    copy(kit["HullGlow"], cyan, Matrix.Translation((0, 0, -4)))
    # The ring: eight segments, each turned to face its island; one glow; screens in the niches.
    ring_z = 92.0
    copy(kit["RingGlow"], cyan, Matrix.Translation((0, 0, ring_z)))
    for k in range(RING_SEGMENTS):
        a = k / RING_SEGMENTS * math.tau
        turn = Matrix.Rotation(a + math.pi / 2, 4, "Z")  # -Y turned to face angle a
        copy(kit["RingSegment"], steel, Matrix.Translation((0, 0, ring_z)) @ turn)
        out = Vector((math.cos(a), math.sin(a), 0))
        prim("box", screen, out * (SCREEN_BACK + 0.15) + Vector((0, 0, ring_z)), (SCREEN_SIZE[0] - 0.6, 0.2, SCREEN_SIZE[1] - 0.6), (0, 0, a + math.pi / 2))
    # Struts from the platform's edge to the ring's underside, between the screens.
    for k in range(4):
        a = math.pi / 8 + k * math.pi / 2
        out = Vector((math.cos(a), math.sin(a), 0))
        foot = out * 61 + Vector((0, 0, -3))
        tip = out * (RING_OUTER - 1.5) + Vector((0, 0, ring_z - RING_HEIGHT / 2))
        rot = (tip - foot).to_track_quat("Z", "Y").to_matrix().to_4x4()
        copy(kit["Pylon"], steel_light, Matrix.Translation(foot) @ rot, (1, 1, (tip - foot).length / PYLON_LENGTH))
    # Kiosks and the coin board in a circle, facing out.
    for k in range(5):
        a = math.pi / 2 + math.pi / 5 + k / 5 * math.tau
        out = Vector((math.cos(a), math.sin(a), 0))
        at = out * 36
        face = Matrix.Translation(at) @ Matrix.Rotation(a + math.pi / 2, 4, "Z")  # -Y faces out
        glow = material(f"Glow{k}", accents[k], emission=4.0)
        if k < 4:
            copy(kit["KioskPearl"], pearl, face)
            copy(kit["KioskDark"], navy, face)
            copy(kit["KioskGlow"], glow, face)
            copy(kit["LabelPlate"], navy, face @ Matrix.Translation(PLATE_CENTRE))
            prim("cyl", navy, face @ Vector((BADGE_CENTRE[0], BADGE_CENTRE[1] + 0.2, BADGE_CENTRE[2])), (2.45, 0.2), (math.pi / 2, 0, a + math.pi / 2))
        else:
            prim("cyl", navy, at + Vector((0, 0, 0.35)), (KIOSK_BASE_RADIUS, 0.7))
            prim("cyl", glow, at + Vector((0, 0, 0.15)), (KIOSK_GLOW_RADIUS, 0.3))
            prim("box", screen, at + Vector((0, 0, 8.7)), (12, 0.6, 12), (0, 0, a + math.pi / 2))

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
    lit = math.pi / 2 + math.pi / 5 + 2 * 2 * math.pi / 5  # a kiosk the sun lights from the front
    first = Vector((math.cos(lit), math.sin(lit), 0))
    kiosk_eye = tuple(first * 62 + Vector((0, 0, 10)))
    kiosk_at = tuple(first * 36 + Vector((0, 0, 9)))
    for name, eye, at, lens in (("far", (355, 4, 17), (0, 0, 40), 19), ("near", (60, 30, 12), (0, -4, 14), 18), ("kiosk", kiosk_eye, kiosk_at, 30)):
        camera_data.lens = lens
        camera.location = eye
        camera.rotation_euler = (Vector(at) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, f"station-kit-{name}.png")
        bpy.ops.render.render(write_still=True)
        print("Wrote", scene.render.filepath)


def sheet(pieces, path):
    """Every piece in a row, lit: a check of the shapes, not the game's look. Big pieces are shown
    shrunk to fit."""
    grey = material("Grey", (0.45, 0.48, 0.55), 0.4, 0.4)
    scene = bpy.context.scene
    copies = []
    x = 0.0
    for piece in pieces:
        low, high = bounds(piece)
        size = max(high - low)
        k = 8.0 / size if size > 8.0 else 1.0
        centre = (low + high) / 2
        copies.append(copy(piece, grey, Matrix.Translation((x, 0, 0)) @ Matrix.Diagonal((k, k, k, 1)) @ Matrix.Translation(-centre)))
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
