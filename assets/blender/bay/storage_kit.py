# The island shelf's kit of meshes (docs/design/screens/storage-shelf.md): the shelf where aliens
# with no place stand, one piece per material class (docs/design/BLENDER_ROBLOX.md, sections 3, 7):
#   Body   - all the plastic: the plinth, boards, crown, back walls, the pearl uprights and the light
#            panels in the niches' ceilings; colours baked in the vertex colours (glTF COLOR_0) as
#            sRGB numbers, the game leaves the part white;
#   Glow   - the light strips at each board's front edge and along the crown (Neon, coloured by the
#            game: the shelf's violet);
#   Origin - a speck at the shelf's origin (on the floor in the arc's middle, halfway into the
#            niches): the game measures where every piece sits from it (World/StorageKit); only in
#            the kit, never placed.
# Front (out of the niches, toward the player) is -Y here, -Z in Roblox; the arc bends toward it.
# The numbers are Config/ShelfShape's: keep them in step (tests/Domain/Shelf.spec.luau compares).
# The shelf is mirror-symmetric, so Blender's X turning into Roblox's -X on import changes nothing.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/bay/storage_kit.py -- <outdir>
# Writes <outdir>/storage-kit.glb and prints the triangles of each piece.

import math
import os
import sys

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/storage_kit")

COLUMNS = 8
TIERS = 3
CELL_WIDTH = 2.5
CELL_HEIGHT = 2.4
DEPTH = 2.3
RADIUS = 22
BASE_HEIGHT = 0.5
BOARD_THICKNESS = 0.18
CROWN_HEIGHT = 0.5
UPRIGHT_WIDTH = 0.3
BACK_THICKNESS = 0.15

# The light strips: on each board's front edge, and along the crown's front.
LIP_HEIGHT, LIP_DEPTH = 0.08, 0.06
STRIP_HEIGHT = 0.12
# A light panel in each niche's ceiling, this far in from its sides and front.
PANEL_INSET, PANEL_THICKNESS = 0.3, 0.04


def to_srgb(linear):
    """A linear colour (the concepts' shader values) as sRGB numbers 0..255."""

    def one(c):
        c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        return round(max(0.0, min(1.0, c)) * 255)

    return tuple(one(c) for c in linear)


# The station's steel, the pets' pearl and the terminals' navy (as the stand, decision 091; the
# same values as concept_storage.py's shaders), and the niches' pale lilac light panels.
COLORS = {
    "steel": to_srgb((0.30, 0.33, 0.42)),
    "dark": to_srgb((0.12, 0.13, 0.19)),
    "pearl": to_srgb((0.84, 0.86, 0.92)),
    "navy": to_srgb((0.035, 0.05, 0.12)),
    "panel": (232, 226, 255),
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


def box(size, location, turn, color, bevel=0.0):
    """A box `size` (along the arc, deep, high) at `location`, turned `turn` about Z, its modifiers
    applied and its colour baked."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=(0, 0, turn))
    obj = bpy.context.active_object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = min(bevel, min(size) * 0.49)
        modifier.segments = 2
        modifier.limit_method = "NONE"
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    paint(obj, COLORS[color])
    return obj


def frame(angle):
    """A point on the arc's middle line, the turn there and the facing (toward the arc's centre,
    which lies in front: the shelf wraps round the path)."""
    x, y = RADIUS * math.sin(angle), -(RADIUS - RADIUS * math.cos(angle))
    facing = Vector((-math.sin(angle), -math.cos(angle), 0))
    return Vector((x, y, 0)), -angle, facing


def column_angle(column):
    """Column 1..COLUMNS's middle (Domain/Shelf.columnAngle, mirrored: see the header)."""
    return (column - (COLUMNS + 1) / 2) * CELL_WIDTH / RADIUS


def build():
    body, glow = [], []
    step = CELL_WIDTH / RADIUS
    top = BASE_HEIGHT + TIERS * CELL_HEIGHT
    height = top + CROWN_HEIGHT
    # A box along the arc is wider at its back than at its front: cover the back's width.
    outer = CELL_WIDTH * (RADIUS + DEPTH / 2) / RADIUS
    for edge in range(COLUMNS + 1):
        at, turn, _ = frame((edge - COLUMNS / 2) * step)
        body.append(box((UPRIGHT_WIDTH, DEPTH + 0.2, height), at + Vector((0, 0, height / 2)), turn, "pearl", 0.1))
    for column in range(1, COLUMNS + 1):
        at, turn, facing = frame(column_angle(column))
        body.append(box((outer, DEPTH + 0.3, BASE_HEIGHT), at + Vector((0, 0, BASE_HEIGHT / 2)), turn, "dark", 0.06))
        body.append(box((outer, DEPTH + 0.3, CROWN_HEIGHT), at + Vector((0, 0, top + CROWN_HEIGHT / 2)), turn, "steel", 0.1))
        back = at - facing * (DEPTH / 2 - BACK_THICKNESS / 2)
        body.append(box((outer, BACK_THICKNESS, TIERS * CELL_HEIGHT), back + Vector((0, 0, BASE_HEIGHT + TIERS * CELL_HEIGHT / 2)), turn, "navy"))
        front = at + facing * (DEPTH / 2 + LIP_DEPTH / 2)
        crown_front = at + facing * ((DEPTH + 0.3) / 2 + LIP_DEPTH / 2)
        glow.append(box((CELL_WIDTH, LIP_DEPTH, STRIP_HEIGHT), crown_front + Vector((0, 0, top + CROWN_HEIGHT / 2)), turn, "glow"))
        for tier in range(1, TIERS + 1):
            floor = BASE_HEIGHT + (tier - 1) * CELL_HEIGHT
            body.append(box((CELL_WIDTH, DEPTH, BOARD_THICKNESS), at + Vector((0, 0, floor + BOARD_THICKNESS / 2)), turn, "steel"))
            glow.append(box((CELL_WIDTH - UPRIGHT_WIDTH, LIP_DEPTH, LIP_HEIGHT), front + Vector((0, 0, floor + BOARD_THICKNESS / 2)), turn, "glow"))
            ceiling = floor + CELL_HEIGHT
            panel = at + facing * (PANEL_INSET / 2)
            size = (CELL_WIDTH - UPRIGHT_WIDTH - PANEL_INSET, DEPTH - BACK_THICKNESS - PANEL_INSET * 2, PANEL_THICKNESS)
            body.append(box(size, panel + Vector((0, 0, ceiling - PANEL_THICKNESS / 2)), turn, "panel"))
    return [join("Body", body), join("Glow", glow), origin()]


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
    paint(obj, COLORS["glow"])
    return obj


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


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    kit = build()
    for piece in kit:
        assert piece.location.length < 1e-6, f"{piece.name} is not about the shelf's origin"
    export(kit, os.path.join(OUT_DIR, "storage-kit.glb"))
