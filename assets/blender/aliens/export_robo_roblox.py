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
    if strength >= 1.0 and max(emission[:3]) > 0.2:
        return {"material": "Neon", "color": colour(emission)}
    if alpha < 0.99:
        return {"material": "Glass", "color": colour(base), "transparency": round(1 - alpha, 2)}
    if inputs["Transmission Weight"].default_value >= 0.5:
        return {"material": "Glass", "color": colour(base), "transparency": 0.35}
    if inputs["Metallic"].default_value >= 0.5:
        return {"material": "SmoothPlastic", "color": colour(base), "reflectance": 0.35, "metal": True}
    return {"material": "SmoothPlastic", "color": colour(base), "reflectance": 0.1 if inputs["Roughness"].default_value < 0.25 else 0.02}


def join_by_role():
    """Real meshes with modifiers applied, effect stand-ins dropped, one object per role and material."""
    for obj in list(bpy.data.objects):
        if obj.type not in ("MESH", "CURVE", "META", "FONT") or obj.get("role") == "fx":
            bpy.data.objects.remove(obj)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    roles = {obj.name: obj.get("role", "body") for obj in bpy.context.selected_objects}
    bpy.ops.object.convert(target="MESH")
    groups = {}
    for obj in bpy.data.objects:
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
        parts[joined.name] = paint_of(bpy.data.materials[material])
    return parts


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    kinds = {kind[0]: kind for kind in robo_kinds.KINDS}
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
                                  export_apply=True, export_yup=True, export_texcoords=False, export_materials="NONE")
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
