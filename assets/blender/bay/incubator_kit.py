# The island incubator's kit of meshes (docs/design/screens/incubator.md, the "bud" concept of
# concept_incubator.py): one piece per material class (docs/design/BLENDER_ROBLOX.md, sections 3, 7):
#   DaisBody - the dais, its pearl rim and the heater in its middle; colours baked in the vertex
#              colours (glTF COLOR_0) as sRGB numbers, the game leaves the part white;
#   DaisGlow - the dais's rim light, the heater's band and top ring (Neon, coloured by the game in
#              the incubator's colour);
#   PodBody  - a bought slot's capsule: the socket, the heater plate, three petals curving up round
#              the egg and the pipe to the heater; colours baked;
#   PodGlow  - all that glows on a capsule: the heater ring, the ring under the egg, the petals'
#              strips and tips, the pipe's strip (Neon, coloured by the game by the capsule's state);
#   BudBody  - a slot not bought yet: the socket with its petals closed into a bud, and the pipe;
#              colours baked, nothing glows;
#   Origin   - a speck at (0, 0, 0): the game measures where every piece sits from it
#              (World/IncubatorKit); only in the kit, never placed.
# The dais is modelled about the incubator's centre on the floor; a capsule and a bud about their
# slot on the dais's top, out of the ring toward -Y here (-Z in Roblox, the slot's look vector),
# the pipe running +Y to the heater. Every piece is mirror-symmetric about X = 0, so Blender's X
# turning into Roblox's -X on import changes nothing.
# The numbers are Config/IncubatorShape's: keep them in step (tests/Domain/Incubator.spec.luau
# compares).
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/bay/incubator_kit.py -- <outdir> [--sheet]
# Writes <outdir>/incubator-kit.glb and prints the triangles of each piece; with --sheet also
# <outdir>/incubator-kit.png: three slots with eggs of the egg kit, as the game shows them.

import math
import os
import sys

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SHEET = "--sheet" in ARGS
ARGS = [a for a in ARGS if a != "--sheet"]
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/incubator_kit")

RING_RADIUS = 9
DAIS_RADIUS = 11.4
DAIS_HEIGHT = 0.6
CORE_RADIUS = 2.6
CORE_HEIGHT = 2.0
SOCKET_RADIUS = 2.0
EGG_FLOOR = 1.45
POD_HEIGHT = 4.6
BUD_HEIGHT = 3.4

# The petals stand away from the slot's front (-Y): the egg's window shows from the path.
PETAL_ANGLES = (math.radians(60), math.radians(180), math.radians(300))
PIPE_RADIUS = 0.2
PIPE_LIFT = 0.2

SEGMENTS = 32


def to_srgb(linear):
    """A linear colour (the concepts' shader values) as sRGB numbers 0..255."""

    def one(c):
        c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        return round(max(0.0, min(1.0, c)) * 255)

    return tuple(one(c) for c in linear)


# The pets' pearl and the station's dark steel (as the stand and the shelf). The dais's top and the
# pipes are a deeper blue steel: a light blue-grey reads pink under the islands' light
# (BLENDER_ROBLOX.md, section 2; the stand's tint, BayLooks.STAND_BODY_TINT, is 120, 135, 190).
COLORS = {
    "pearl": to_srgb((0.84, 0.86, 0.92)),
    "dark": to_srgb((0.12, 0.13, 0.19)),
    "deck": (70, 82, 122),
    "pipe": (120, 135, 190),
    "glow": (255, 255, 255),
}


def paint(obj, rgb):
    """One baked colour for the whole object. Roblox reads glTF COLOR_0 as sRGB numbers: they go
    into the attribute as they are, through the linear setter (BLENDER_ROBLOX.md, section 2)."""
    mesh = obj.data
    attribute = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0)
    mesh.color_attributes.active_color = attribute
    return obj


def mesh_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj


def apply_modifiers(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def lathe(name, profile, color, segments=SEGMENTS, lobes=0.0):
    """A solid of revolution about Z: `profile` is [(radius, z), ...] bottom to top; a radius of
    0 at an end closes it with a pole. `lobes` swells it into three lobes between the petals'
    places (a closed bud)."""
    bm = bmesh.new()
    rings = []
    for radius, z in profile:
        if radius == 0:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            r = radius * (1 + lobes * math.cos(3 * (a - PETAL_ANGLES[0])))
            ring.append(bm.verts.new((r * math.sin(a), -r * math.cos(a), z)))
        rings.append(ring)
    for low, high in zip(rings, rings[1:]):
        if len(low) == 1:
            for i in range(segments):
                bm.faces.new((low[0], high[(i + 1) % segments], high[i]))
        elif len(high) == 1:
            for i in range(segments):
                bm.faces.new((low[i], low[(i + 1) % segments], high[0]))
        else:
            for i in range(segments):
                j = (i + 1) % segments
                bm.faces.new((low[i], low[j], high[j], high[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return paint(mesh_object(name, bm), COLORS[color])


def torus(name, major, minor, location, color, segments=SEGMENTS, minor_segments=8, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=location, rotation=rotation,
                                     major_segments=segments, minor_segments=minor_segments)
    obj = bpy.context.active_object
    obj.name = name
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return paint(obj, COLORS[color])


def ball(name, radius, location, color):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=12, ring_count=6)
    obj = bpy.context.active_object
    obj.name = name
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return paint(obj, COLORS[color])


def tube(name, radius, start, end, color, segments=12):
    """A cylinder from `start` to `end`."""
    start, end = Vector(start), Vector(end)
    axis = end - start
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=axis.length, location=(start + end) / 2, vertices=segments)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return paint(obj, COLORS[color])


def blade(name, path, widths, thickness, side, color):
    """A curved flat blade along `path`, `widths` across it along `side`, `thickness` through it;
    its edges rounded."""
    bm = bmesh.new()
    slices = []
    for index, point in enumerate(path):
        ahead = path[min(index + 1, len(path) - 1)] - path[max(index - 1, 0)]
        normal = ahead.cross(side).normalized()
        half_w = side * widths[index] / 2
        half_t = normal * thickness / 2
        slices.append([bm.verts.new(point + s * half_w + t * half_t) for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for low, high in zip(slices, slices[1:]):
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((low[i], low[j], high[j], high[i]))
    bm.faces.new(slices[0][::-1])
    bm.faces.new(slices[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_object(name, bm)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = thickness * 0.45
    modifier.segments = 2
    apply_modifiers(obj)
    return paint(obj, COLORS[color])


def outward(angle):
    """The unit vector `angle` round from the slot's front (-Y)."""
    return Vector((math.sin(angle), -math.cos(angle), 0))


# --- The dais --------------------------------------------------------------------------------------


def dais():
    body = [
        lathe("Deck", [(0, 0), (DAIS_RADIUS - 0.4, 0), (DAIS_RADIUS, 0.15), (DAIS_RADIUS, DAIS_HEIGHT - 0.12),
                       (DAIS_RADIUS - 0.25, DAIS_HEIGHT), (0, DAIS_HEIGHT)], "deck", 96),
        torus("Rim", DAIS_RADIUS - 0.35, 0.09, (0, 0, DAIS_HEIGHT), "pearl", 96, 6),
        lathe("Core", [(CORE_RADIUS, DAIS_HEIGHT), (CORE_RADIUS, DAIS_HEIGHT + 0.5), (2.2, DAIS_HEIGHT + 1.4),
                       (1.4, DAIS_HEIGHT + 1.9), (0, DAIS_HEIGHT + CORE_HEIGHT)], "pearl", 48),
    ]
    glow = [
        torus("RimLight", DAIS_RADIUS - 0.03, 0.07, (0, 0, DAIS_HEIGHT * 0.55), "glow", 96, 6),
        lathe("CoreBand", [(CORE_RADIUS + 0.02, DAIS_HEIGHT + 0.62), (CORE_RADIUS - 0.12, DAIS_HEIGHT + 0.98),
                           (CORE_RADIUS - 0.14, DAIS_HEIGHT + 1.0), (CORE_RADIUS, DAIS_HEIGHT + 0.64)], "glow", 48),
        torus("CoreTop", 0.9, 0.12, (0, 0, DAIS_HEIGHT + CORE_HEIGHT - 0.05), "glow", 32, 8),
    ]
    return join("DaisBody", body), join("DaisGlow", glow)


# --- A slot: an open capsule or a closed bud ---------------------------------------------------------

SOCKET = [(0, 0), (1.9, 0), (SOCKET_RADIUS, 0.25), (1.6, 0.9), (1.35, 1.0), (0, 1.0)]


def pipe(glowing):
    """The pipe from the socket to the heater, along +Y; its lit strip when `glowing`."""
    end = RING_RADIUS - CORE_RADIUS + 0.15
    body = tube("Pipe", PIPE_RADIUS, (0, 1.6, PIPE_LIFT), (0, end, PIPE_LIFT), "pipe")
    light = tube("PipeLight", 0.07, (0, 1.8, PIPE_LIFT + 0.19), (0, end - 0.1, PIPE_LIFT + 0.19), "glow", 8)
    if not glowing:
        bpy.data.objects.remove(light, do_unlink=True)
        return [body], []
    return [body], [light]


def petal_path(angle):
    out = outward(angle)
    path, widths = [], []
    steps = 10
    for i in range(steps + 1):
        t = i / steps
        radius = 1.55 + 0.75 * math.sin(t * math.pi * 0.85) - 0.35 * t
        path.append(out * radius + Vector((0, 0, 0.8 + 3.6 * t)))
        widths.append(1.05 - 0.75 * t)
    return out, path, widths


def pod():
    body = [
        lathe("Socket", SOCKET, "pearl"),
        lathe("Plate", [(0, 1.0), (1.3, 1.0), (1.2, 1.12), (0, 1.12)], "dark"),
    ]
    glow = [
        torus("Heater", 1.05, 0.09, (0, 0, 1.14), "glow"),
        # A ring of light under the hovering egg.
        torus("Halo", 0.75, 0.05, (0, 0, EGG_FLOOR - 0.15), "glow", 24, 6),
    ]
    for angle in PETAL_ANGLES:
        out, path, widths = petal_path(angle)
        side = Vector((-out.y, out.x, 0))
        body.append(blade("Petal", path, widths, 0.2, side, "pearl"))
        inner = [p - out * 0.13 for p in path[2:-1]]
        glow.append(blade("PetalLight", inner, [0.16] * len(inner), 0.06, side, "glow"))
        glow.append(ball("Tip", 0.2, path[-1] + Vector((0, 0, 0.12)), "glow"))
    pipe_body, pipe_light = pipe(True)
    return join("PodBody", body + pipe_body), join("PodGlow", glow + pipe_light)


BUD = [(1.35, 0.9), (1.55, 1.6), (1.3, 2.5), (0.6, 3.2), (0, BUD_HEIGHT)]
BUD_LOBES = 0.08


def bud():
    body = [
        lathe("Socket", SOCKET, "pearl"),
        # The petals closed: three lobes, each where its petal stands open.
        lathe("Bud", BUD, "pearl", lobes=BUD_LOBES),
        ball("Tip", 0.14, (0, 0, BUD_HEIGHT), "dark"),
    ]
    # Dark seams where the petals meet, halfway between their places, along the bud's surface.
    for angle in PETAL_ANGLES:
        out = outward(angle + math.pi / 3)
        side = Vector((-out.y, out.x, 0))
        path = [out * (radius * (1 - BUD_LOBES) + 0.01) + Vector((0, 0, z)) for radius, z in BUD[1:-1]]
        body.append(blade("Seam", path, [0.1] * len(path), 0.06, side, "dark"))
    pipe_body, _ = pipe(False)
    return join("BudBody", body + pipe_body)


# --- The kit -----------------------------------------------------------------------------------------


def join(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = obj.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def origin():
    bpy.ops.mesh.primitive_cube_add(size=0.02, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Origin"
    return paint(obj, COLORS["glow"])


# Piece names are the game's (World/IncubatorKit, BayModel): keep them in step.
def build():
    dais_body, dais_glow = dais()
    pod_body, pod_glow = pod()
    return [dais_body, dais_glow, pod_body, pod_glow, bud(), origin()]


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
    print("Wrote", path, os.path.getsize(path), "bytes:", ", ".join(f"{p.name} {triangles(p)} triangles" for p in pieces))


# --- The check sheet: three slots with eggs, as the game shows them --------------------------------


def sheet(pieces, path):
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "eggs"))
    import egg_kit
    from mathutils import Matrix

    kit = {piece.name: piece for piece in pieces}
    for piece in pieces:
        piece.hide_render = True
    eggs = {piece.name: piece for piece in egg_kit.build()}
    for piece in eggs.values():
        piece.hide_render = True

    def lit(rgb, strength):
        return egg_kit.neon(rgb, strength)

    def wear(name, matrix, material):
        copy = kit[name].copy()
        copy.data = kit[name].data.copy()
        copy.hide_render = False
        bpy.context.scene.collection.objects.link(copy)
        copy.matrix_world = matrix
        copy.data.materials.clear()
        copy.data.materials.append(material)

    wear("DaisBody", Matrix(), egg_kit.baked())
    wear("DaisGlow", Matrix(), lit((255, 170, 60), 2.5))
    # Slots as the game numbers them (the first faces the entrance, -Y).
    slots = [
        ("Legendary", 1.5, (90, 240, 110)),
        ("Rare", 1.0, (255, 170, 60)),
        ("Uncommon", 0.65, (255, 170, 60)),
        (None, 0, None),
    ]
    for index in range(1, 13):
        step = 2 * math.pi / 12
        offset = math.ceil((index - 1) / 2) * (1 if index % 2 == 0 else -1)
        angle = offset * step
        frame = (Matrix.Translation((RING_RADIUS * math.sin(angle), -RING_RADIUS * math.cos(angle), DAIS_HEIGHT))
                 @ Matrix.Rotation(angle, 4, "Z"))
        if index > len(slots):
            wear("BudBody", frame, egg_kit.baked())
            continue
        rarity, scale, color = slots[index - 1]
        wear("PodBody", frame, egg_kit.baked())
        wear("PodGlow", frame, lit(color or (255, 170, 60), 2.5 if color else 0.4))
        if rarity:
            bottom = frame @ Vector((0, 0, EGG_FLOOR))
            egg_kit.dress(eggs, bottom, rarity, scale)
            for obj in bpy.context.scene.objects:
                if obj.location == bottom + Vector((0, 0, egg_kit.HALF_HEIGHT * scale)):
                    obj.rotation_euler = (0, 0, angle)
    egg_kit.render(Vector((0, -6, 2)), path, size=(2400, 1500), distance=30)


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    kit = build()
    for piece in kit:
        assert piece.location.length < 1e-6, f"{piece.name} is not about the kit's origin"
    export(kit, os.path.join(OUT_DIR, "incubator-kit.glb"))
    if SHEET:
        sheet(kit, os.path.join(OUT_DIR, "incubator-kit.png"))
