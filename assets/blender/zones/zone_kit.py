# The zones' kit of meshes (docs/plans/ZONES.md, step 1): the shapes the field, the nests and the
# zones' dressing are made of in game. One GLB, one node per piece, a row along X. The game gives
# every copy its size, turn, material and colour (World/ZoneKit), so one rock shape serves every
# zone: grey slate in the Debris Belt, snow in the Ice Rings, basalt in the Red Nebula.
#
# Rocks carry their shading in vertex colours (glTF COLOR_0, grey: dark crater bowls, mottling);
# Roblox multiplies them by the part's colour (export_robo_roblox.py, "Baked"). UVs are kept for
# the Roblox material's texture.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/zones/zone_kit.py -- <outdir> [--sheet]
# Writes <outdir>/zone-kit.glb; with --sheet also <outdir>/zone-kit.png, every piece in a row.

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SHEET = "--sheet" in ARGS
ARGS = [a for a in ARGS if a != "--sheet"]
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/zone_kit")

# Every rock is modelled this big (radius, studs); the game sizes each copy itself.
RADIUS = 5.0
# Ico sphere subdivisions of a rock: 1280 triangles, enough for lumps and craters at a distance.
ROCK_DETAIL = 4


# --- Shapes --------------------------------------------------------------------------------------


def fbm(point, octaves=4):
    """Fractal noise around 0, about -1..1."""
    total, amplitude, frequency = 0.0, 1.0, 1.0
    for _ in range(octaves):
        total += amplitude * noise.noise(point * frequency)
        amplitude *= 0.5
        frequency *= 2.0
    return total


def crater_centres(rng, count):
    centres = []
    for _ in range(count):
        v = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        centres.append((v, rng.uniform(0.22, 0.5)))
    return centres


def crater_depth(direction, craters):
    """How deep the craters press a point of the unit sphere in: a bowl with a little raised rim.
    Returns (depth, bowl): bowl is 1 at a crater's bottom and 0 outside, for the shading."""
    depth, bowl = 0.0, 0.0
    for centre, size in craters:
        d = (direction - centre).length / size
        if d < 1.0:
            depth = max(depth, (1.0 - d * d) * size * 0.4)
            bowl = max(bowl, 1.0 - d * d)
        elif d < 1.4:
            depth -= math.sin((d - 1.0) / 0.4 * math.pi) * size * 0.08
    return depth, bowl


def new_object(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def rock(name, seed, lumps=0.28, craters=5, holes=0, flat_top=False, faceted=False):
    """An asteroid: an ico sphere pushed in and out by noise, with crater bowls. `holes` adds small
    deep pits (pumice); `flat_top` cuts the top off flat (a nest rock: the pad stands there);
    `faceted` keeps few big flat faces (an ice chunk). Shading goes into the vertex colours."""
    rng = random.Random(seed)
    offset = Vector((rng.uniform(-50, 50), rng.uniform(-50, 50), rng.uniform(-50, 50)))
    bm = bmesh.new()
    shades = {}
    if faceted:
        # A chunk of ice: the hull of scattered points, a few big uneven faces.
        for _ in range(16):
            direction = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
            bm.verts.new(direction * rng.uniform(0.75, 1.05) * Vector((1.0, 0.85, 1.25)))
        hull = bmesh.ops.convex_hull(bm, input=list(bm.verts))
        inside = list({v for v in hull["geom_interior"] + hull["geom_unused"] if isinstance(v, bmesh.types.BMVert)})
        bmesh.ops.delete(bm, geom=inside, context="VERTS")
    else:
        bmesh.ops.create_icosphere(bm, subdivisions=ROCK_DETAIL, radius=1.0)
    pits = crater_centres(rng, craters) + [(c, s * 0.3) for c, s in crater_centres(rng, holes)]
    # Not quite round: stretched a little along a random axis.
    stretch = Vector((rng.uniform(0.85, 1.15), rng.uniform(0.85, 1.1), rng.uniform(0.8, 1.05)))
    for v in bm.verts:
        if faceted:
            shades[v.index] = (0.0, 0.0)
            continue
        direction = v.co.normalized()
        lump = fbm(direction * 1.1 + offset, 3) * lumps
        grain = noise.noise(direction * 6.0 + offset) * lumps * 0.08
        dent, bowl = crater_depth(direction, pits)
        r = 1.0 + lump + grain - dent
        v.co = direction * r * stretch
        shades[v.index] = (bowl, fbm(direction * 2.5 + offset * 2.0, 3))
    if flat_top:
        # Everything above this height is pressed down onto it: a flat top for the pad.
        top = 0.45
        for v in bm.verts:
            if v.co.z > top:
                v.co.z = top + (v.co.z - top) * 0.04
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = not faceted
    obj = new_object(name, mesh)
    obj.scale = (RADIUS, RADIUS, RADIUS)
    shade_rock(obj, shades, faceted)
    return obj


def shade_rock(obj, shades, faceted):
    """Grey shading in the vertex colours: crater bowls darker, mottled light and dark patches,
    crevices (where the surface is pushed in) a little darker. White for an ice chunk."""
    mesh = obj.data
    attribute = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for loop in mesh.loops:
        vertex = mesh.vertices[loop.vertex_index]
        if faceted:
            value = 1.0
        else:
            bowl, mottle = shades[vertex.index]
            crevice = max(0.0, 1.0 - vertex.co.length) * 1.2
            value = 0.86 + mottle * 0.28 - bowl * 0.45 - crevice
            value = min(1.0, max(0.28, value))
        attribute.data[loop.index].color_srgb = (value, value, value, 1.0)
    mesh.color_attributes.active_color = attribute


def join(name, parts):
    """Joins the objects into one mesh named `name` (one MeshPart in game)."""
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    # The joined parts' centre at the origin, so the game's size and turn apply about it.
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    obj.location = (0, 0, 0)
    return obj


def pebbles(name, seed):
    """A cluster of small rocks (one mesh)."""
    rng = random.Random(seed)
    parts = []
    for i in range(7):
        part = rock(f"{name}_{i}", seed * 100 + i, lumps=0.34, craters=2)
        size = rng.uniform(0.2, 0.42)
        part.scale = (RADIUS * size,) * 3
        part.location = (rng.uniform(-0.6, 0.6) * RADIUS, rng.uniform(-0.45, 0.45) * RADIUS, rng.uniform(-0.4, 0.4) * RADIUS)
        part.rotation_euler = (rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3))
        parts.append(part)
    return join(name, parts)


def spike_mesh(name, length=1.0, radius=0.18, sides=6):
    """A crystal: a six-sided prism with a pointed tip, along +Z from the origin."""
    bm = bmesh.new()
    ring = []
    for i in range(sides):
        a = i / sides * math.tau
        ring.append((math.cos(a) * radius, math.sin(a) * radius))
    bottom = [bm.verts.new((x, y, 0)) for x, y in ring]
    shoulder = [bm.verts.new((x, y, length * 0.72)) for x, y in ring]
    tip = bm.verts.new((0, 0, length))
    bm.faces.new(list(reversed(bottom)))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((bottom[i], bottom[j], shoulder[j], shoulder[i]))
        bm.faces.new((shoulder[i], shoulder[j], tip))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return new_object(name, mesh)


def white(obj):
    attribute = obj.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color_srgb = (1.0, 1.0, 1.0, 1.0)
    obj.data.color_attributes.active_color = attribute


def crystals(name, seed, count):
    """A bunch of crystals growing out of one spot, mostly upward (+Z)."""
    rng = random.Random(seed)
    parts = []
    for i in range(count):
        part = spike_mesh(f"{name}_{i}", rng.uniform(1.0, 1.9) * RADIUS, rng.uniform(0.14, 0.24) * RADIUS)
        direction = Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), rng.uniform(0.35, 1.0))).normalized()
        part.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
        parts.append(part)
    obj = join(name, parts)
    white(obj)
    return obj


def ring(name, minor=0.035, segments=72):
    """A thin ring, radius 1 x RADIUS, lying flat (the nest's rim and cradle, gravity rings)."""
    bpy.ops.mesh.primitive_torus_add(major_radius=RADIUS, minor_radius=RADIUS * minor, major_segments=segments, minor_segments=10)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = True
    white(obj)
    return obj


def uv(obj):
    """UVs for the Roblox material's texture: a smart projection, islands at the mesh's own scale."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


# --- The kit -------------------------------------------------------------------------------------

# Piece names are the game's (ZoneLooks): keep them in step.
def build():
    pieces = [
        rock("Rock1", 11),
        rock("Rock2", 12, lumps=0.34, craters=7),
        rock("Rock3", 13, lumps=0.22, craters=3),
        rock("Smooth1", 21, lumps=0.14, craters=2),
        rock("Smooth2", 22, lumps=0.18, craters=3),
        rock("Holey", 31, lumps=0.3, craters=3, holes=26),
        rock("NestRock1", 41, lumps=0.2, craters=4, flat_top=True),
        rock("NestRock2", 42, lumps=0.26, craters=3, flat_top=True),
        pebbles("Pebbles1", 51),
        pebbles("Pebbles2", 52),
        rock("IceChunk1", 61, faceted=True),
        rock("IceChunk2", 62, faceted=True),
        crystals("Crystals1", 71, 9),
        crystals("Crystals2", 72, 6),
        ring("Ring"),
    ]
    for piece in pieces:
        uv(piece)
    return pieces


def export(pieces, path):
    x = 0.0
    for piece in pieces:
        piece.location = (x, 0, 0)
        x += RADIUS * 3
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    options = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=True, export_materials="NONE")
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    triangles = sum(sum(len(p.vertices) - 2 for p in piece.data.polygons) for piece in pieces)
    print("Wrote", path, len(pieces), "pieces", triangles, "triangles", os.path.getsize(path), "bytes")


def sheet(pieces, path):
    """Every piece in a row, lit, vertex colours shown: a check of the shapes, not the game's look."""
    mat = bpy.data.materials.new("VertexGrey")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.9
    colour = nodes.new("ShaderNodeVertexColor")
    colour.layer_name = "Col"
    tint = nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    tint.inputs[7].default_value = (0.55, 0.5, 0.47, 1)
    links.new(colour.outputs["Color"], tint.inputs[6])
    links.new(tint.outputs[2], bsdf.inputs["Base Color"])
    for piece in pieces:
        piece.data.materials.clear()
        piece.data.materials.append(mat)
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Space")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.01, 0.01, 0.02, 1)
    scene.world = world
    span = RADIUS * 3 * (len(pieces) - 1)
    for name, location, energy in (("Key", (span * 0.3, -40, 40), 3.5), ("Fill", (span * 0.7, -30, -10), 1.2)):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        light = new_object(name, data)
        light.rotation_euler = (Vector((span / 2, 0, 0)) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    camera_data = bpy.data.cameras.new("Cam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = span + RADIUS * 4
    camera = new_object("Cam", camera_data)
    camera.location = (span / 2, -100, 14)
    camera.rotation_euler = (math.radians(82), 0, 0)
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 2400, 420
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Wrote", path)


bpy.ops.wm.read_factory_settings(use_empty=True)
os.makedirs(OUT_DIR, exist_ok=True)
kit = build()
export(kit, os.path.join(OUT_DIR, "zone-kit.glb"))
if SHEET:
    sheet(kit, os.path.join(OUT_DIR, "zone-kit.png"))
