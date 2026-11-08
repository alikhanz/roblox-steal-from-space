# Exports robot pets for a look in Roblox Studio (decision 074): one GLB per pet and a JSON sidecar.
#
# Parts are joined by role and material (robo.py tags every part with its role), so each becomes one
# MeshPart named <role>_<n>: the game can move the ones that move (wings, rotor, drones, orbits,
# rays) and paint each from the sidecar (colour and a Roblox material: Neon for glow, Glass for
# domes and crystals, CrackedLava for a meteor's molten shell, SmoothPlastic for the rest). Parts
# that only stand in for effects (role "fx": motes, sparkles, embers, comet tails) are left out:
# the game plays particles there instead. The sidecar also names the pet (kind, zone, family, tier,
# meteor, signature parts) and its colours, so the game can pick the particles.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/export_robo_roblox.py -- <outdir> <kind id>:<0..4 | m0..m4> ...

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import export_robo_glb  # noqa: E402,F401  (swaps the patterned finishes for flat ones)
import robo  # noqa: E402
import robo_kinds  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = ARGS[0] if ARGS else "out/robo_roblox"
SPECS = ARGS[1:]
robo.DETAIL = 0.8


def srgb(channel):
    channel = max(0.0, min(1.0, channel))
    return round(channel * 12.92 if channel <= 0.0031308 else 1.055 * channel ** (1 / 2.4) - 0.055, 3)


def colour(rgb):
    return [srgb(c) for c in rgb[:3]]


def paint_of(mat):
    """How Studio paints a part of this material."""
    inputs = mat.node_tree.nodes.get("Principled BSDF").inputs
    base = list(inputs["Base Color"].default_value)
    emission = list(inputs["Emission Color"].default_value)
    strength = inputs["Emission Strength"].default_value
    alpha = inputs["Alpha"].default_value
    if mat.name.startswith("Meteor"):
        return {"material": "CrackedLava", "color": [0.35, 0.12, 0.05]}
    # See-through first: a crystal, jelly or aura that also glows a little is still glass in game
    # (as Neon it burns to a solid white spike under Bloom).
    if alpha < 0.99:
        return {"material": "Glass", "color": colour(base), "transparency": round(1 - alpha, 2)}
    if inputs["Transmission Weight"].default_value >= 0.5:
        return {"material": "Glass", "color": colour(base), "transparency": 0.35}
    if strength >= 1.0 and max(emission[:3]) > 0.2:
        return {"material": "Neon", "color": colour(emission)}
    if inputs["Metallic"].default_value >= 0.5:
        return {"material": "SmoothPlastic", "color": colour(base), "reflectance": 0.35, "metal": True}
    return {"material": "SmoothPlastic", "color": colour(base), "reflectance": 0.1 if inputs["Roughness"].default_value < 0.25 else 0.02}


# A meteor's molten shell wears the lava crack texture in game (lava_texture.py): one tile spans this
# many Blender units, so its cells come out about the size the renders' procedural cracks have.
LAVA_TILE = 1.5


def lava_uvs():
    """Box-projected UVs on the molten parts, in world units (so the cracks are one size all over the
    pet and match across joined parts); no UVs on the rest, which wear flat colour."""
    for obj in bpy.context.view_layer.objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        molten = bool(mesh.materials) and mesh.materials[0] is not None and mesh.materials[0].name.startswith("Meteor")
        while mesh.uv_layers:
            mesh.uv_layers.remove(mesh.uv_layers[0])
        if not molten:
            continue
        layer = mesh.uv_layers.new(name="UVMap")
        world = obj.matrix_world
        rotation = world.to_3x3()
        for polygon in mesh.polygons:
            normal = rotation @ polygon.normal
            axis = max(range(3), key=lambda i: abs(normal[i]))
            u, v = [(1, 2), (0, 2), (0, 1)][axis]
            for loop in polygon.loop_indices:
                point = world @ mesh.vertices[mesh.loops[loop].vertex_index].co
                layer.data[loop].uv = (point[u] / LAVA_TILE, point[v] / LAVA_TILE)


def join_by_role():
    """Real meshes with modifiers applied, effect stand-ins dropped, one object per role and material.
    Works on the objects of the view layer only (a pack keeps finished pets out of it)."""
    for obj in list(bpy.context.view_layer.objects):
        if obj.type not in ("MESH", "CURVE", "META", "FONT") or obj.get("role") == "fx":
            bpy.data.objects.remove(obj)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    roles = {obj.name: obj.get("role", "body") for obj in bpy.context.selected_objects}
    bpy.ops.object.convert(target="MESH")
    lava_uvs()
    groups = {}
    for obj in bpy.context.view_layer.objects:
        if obj.type == "MESH" and obj.data.materials and obj.data.materials[0]:
            key = (roles.get(obj.name, obj.get("role", "body")), obj.data.materials[0].name)
            groups.setdefault(key, []).append(obj)
    parts = {}
    for index, ((role, material), objects) in enumerate(sorted(groups.items())):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = joined.data.name = f"{role}_{index}"
        # The Blender material's name goes along, so the game (and a check of the render against
        # the game) knows what a part is, not only its colour.
        parts[joined.name] = {**paint_of(bpy.data.materials[material]), "source": material.split(".")[0]}
    return parts


def rgb255(c):
    return ",".join(str(round(v * 255)) for v in c[:3])


def paint_code(paint):
    """A part's paint in a few characters: <S|N|G|L>r,g,b,transparency,reflectance,<material>."""
    letter = {"SmoothPlastic": "S", "Neon": "N", "Glass": "G", "CrackedLava": "L"}[paint["material"]]
    return f"{letter}{rgb255(paint['color'])},{paint.get('transparency', 0):g},{paint.get('reflectance', 0):g},{paint['source']}"


def marker(name, location):
    """A tiny tetrahedron that only carries a name (a glTF node needs geometry to reach Roblox)."""
    mesh = bpy.data.meshes.new(name)
    s = 0.02
    mesh.from_pydata([(0, 0, 0), (s, 0, 0), (0, s, 0), (0, 0, s)], [], [(0, 1, 2), (0, 1, 3), (0, 2, 3), (1, 2, 3)])
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    return obj


PACK_VARIANTS = ["0", "1", "2", "3", "4", "m0", "m1", "m2", "m3", "m4"]
PACK_SPACING = 12.0


def pack(kind):
    """All ten variants of a kind (five tiers, plain and meteor) in one GLB, a row of pets. Everything
    the game needs rides in the node names, so nothing is copied by hand into Studio:
      <variant>|<role>_<n>|<paint code>              a part;
      <variant>|meta1|zone|family|tier|meteor|sig    and
      <variant>|meta2|glow|core|tierColor|shell      the pet (tiny marker nodes)."""
    kind_id = kind[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    packed = bpy.data.collections.new("Packed")
    bpy.context.scene.collection.children.link(packed)
    colours = robo.theme(kind[3], kind[4])["colours"]
    for index, variant in enumerate(PACK_VARIANTS):
        meteor = variant.startswith("m")
        tier = int(variant.lstrip("m"))
        robo_kinds.build(kind, tier, 0.0, 0.0, meteor)
        parts = join_by_role()
        x = index * PACK_SPACING
        finished = []
        for obj in list(bpy.context.view_layer.objects):
            if obj.type != "MESH":
                continue
            paint = parts.get(obj.name)
            if paint is None:
                bpy.data.objects.remove(obj)
                continue
            obj.name = obj.data.name = f"{variant}|{obj.name}|{paint_code(paint)}"
            finished.append(obj)
        signature = "+".join(part.__name__ for part in kind[6])
        finished.append(marker(f"{variant}|meta1|{kind[3]}|{kind[2]}|{tier}|{str(meteor).lower()}|{signature}", (0, 0, -1)))
        finished.append(marker(f"{variant}|meta2|{rgb255(colour(colours['glow']))}|{rgb255(colour(colours['core']))}|{rgb255(colour(robo.TIER_COLORS[tier]))}|{rgb255(colour(colours['shell']))}", (0, 0, -1)))
        for obj in finished:
            if len(obj.name) > 62:
                raise ValueError(f"name too long for Blender: {obj.name}")
            obj.location.x += x
            for collection in list(obj.users_collection):
                collection.objects.unlink(obj)
            packed.objects.link(obj)
        # Finished pets leave the view layer, so the next build and join leave them alone.
        bpy.context.view_layer.layer_collection.children["Packed"].exclude = True
    bpy.context.view_layer.layer_collection.children["Packed"].exclude = False
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT_DIR, f"pack-{kind_id}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_materials="NONE")
    print("Packed", kind_id, len(bpy.context.selected_objects), "nodes", os.path.getsize(path), "bytes")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    kinds = {kind[0]: kind for kind in robo_kinds.KINDS}
    if SPECS and SPECS[0] == "--pack":
        for kind_id in SPECS[1:] or list(kinds):
            pack(kinds[kind_id])
        return
    for spec in SPECS:
        kind_id, variant = spec.split(":")
        meteor = variant.startswith("m")
        tier = int(variant.lstrip("m"))
        kind = kinds[kind_id]
        bpy.ops.wm.read_factory_settings(use_empty=True)
        robo_kinds.build(kind, tier, 0.0, 0.0, meteor)
        parts = join_by_role()
        name = f"{kind_id}-{variant}"
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, name + ".glb"), export_format="GLB", use_selection=True,
                                  export_apply=True, export_yup=True, export_texcoords=True, export_materials="NONE")
        colours = robo.theme(kind[3], kind[4])["colours"]
        meta = {
            "kind": kind_id, "zone": kind[3], "family": kind[2], "tier": tier, "meteor": meteor, "slot": kind[8],
            "signature": [part.__name__ for part in kind[6]],
            "colors": {key: colour(colours[key]) for key in ("shell", "trim", "glow", "eyes", "core")},
            "tierColor": colour(robo.TIER_COLORS[tier]),
        }
        with open(os.path.join(OUT_DIR, name + ".json"), "w", encoding="utf-8") as file:
            json.dump({"meta": meta, "parts": parts}, file)
        print("Exported", name, len(parts), "parts")


main()
