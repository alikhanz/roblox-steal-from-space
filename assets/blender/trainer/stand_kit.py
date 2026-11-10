# The jetpack stand's kit of meshes (decision 091): the six tiers of stand.py at the game's
# detail, one piece per material class a tier (docs/design/BLENDER_ROBLOX.md, sections 3 and 7):
#   Body<n>  - all the plastic: steel, light steel, dark trim, pearl ceramic, navy faces, the
#              platform's top; colours baked in the vertex colours (glTF COLOR_0) as sRGB numbers,
#              the game leaves the part white (SmoothPlastic);
#   Glow<n>  - the trainer's yellow light (Neon, coloured by the game);
#   Grate<n> - where the flame lands: the grate in the platform, its hot rings, the ducts' mouths
#              (Neon, heated by the client while the owner trains; the stand's StandGrate);
#   Pilot<n> - the pilot lights (Neon, shown by the client while the stand is empty; StandPilot);
#   Gold6    - the top tier's gold (Metal, PetMetal);
#   Origin   - a speck at the stand's origin (the platform's centre on the floor): the game measures
#              where every piece sits from it (World/StandKit); only in the kit, never placed.
# Every tier is built at the same origin, the rider's front -Y here (-Z, the look vector, in
# Roblox). The level dial's lamps are plain parts the game sets per level.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/trainer/stand_kit.py -- <outdir>
# Writes <outdir>/stand-kit.glb and prints the triangles of each piece.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import stand  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/stand_kit")


def to_srgb(linear):
    """A linear colour (the concepts' shader values) as sRGB numbers 0..255."""

    def one(c):
        c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        return round(max(0.0, min(1.0, c)) * 255)

    return tuple(one(c) for c in linear)


# The body's baked colours: the station's steel (as the terminals, decision 086), the pets'
# pearl, the terminals' navy; the same values as concept_stand.py's shaders.
BODY_COLORS = {
    "steel": to_srgb((0.30, 0.33, 0.42)),
    "light": to_srgb((0.72, 0.75, 0.82)),
    "dark": to_srgb((0.12, 0.13, 0.19)),
    "top": to_srgb((0.12, 0.13, 0.19)),
    "pearl": to_srgb((0.84, 0.86, 0.92)),
    "navy": to_srgb((0.035, 0.05, 0.12)),
}
WHITE = (255, 255, 255)

# Which piece each role goes into.
CLASSES = {
    **{role: "Body" for role in BODY_COLORS},
    "glow": "Glow",
    "hot": "Grate",
    "pilot": "Pilot",
    "gold": "Gold",
}


def paint(obj, rgb):
    """One baked colour for the whole object. Roblox reads glTF COLOR_0 as sRGB numbers: they go
    into the attribute as they are, through the linear setter (BLENDER_ROBLOX.md, section 2)."""
    mesh = obj.data
    attribute = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0)
    mesh.color_attributes.active_color = attribute


def apply_modifiers(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def join(name, parts):
    """The parts as one object `name`, its origin the stand's (everything baked into the mesh)."""
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


def tier_pieces(tier):
    objects = stand.build(tier)
    groups = {}
    for obj in objects:
        role = obj["role"]
        apply_modifiers(obj)
        paint(obj, BODY_COLORS.get(role, WHITE))
        groups.setdefault(CLASSES[role], []).append(obj)
    pieces = []
    for kind, parts in groups.items():
        name = f"{kind}{tier}"
        pieces.append(join(name, parts))
    return pieces


def origin():
    bpy.ops.mesh.primitive_cube_add(size=0.02, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = obj.data.name = "Origin"
    paint(obj, WHITE)
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
    print("Wrote", path, len(pieces), "pieces", os.path.getsize(path), "bytes")
    for tier in range(1, len(stand.TIERS) + 1):
        worn = [piece for piece in pieces if piece.name.endswith(str(tier)) and piece.name != "Origin"]
        print(f"  tier {tier}: {sum(triangles(p) for p in worn)} triangles in {len(worn)} pieces:",
              ", ".join(f"{p.name} {triangles(p)}" for p in worn))


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    stand.LOW_POLY = True
    stand.MATERIALS.clear()
    kit = []
    for tier in range(1, len(stand.TIERS) + 1):
        kit += tier_pieces(tier)
    kit.append(origin())
    for piece in kit:
        assert piece.location.length < 1e-6, f"{piece.name} is not about the stand's origin"
    export(kit, os.path.join(OUT_DIR, "stand-kit.glb"))
