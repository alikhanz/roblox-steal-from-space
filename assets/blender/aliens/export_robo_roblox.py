# Exports robot pets for a look in Roblox Studio (decision 074): one GLB per pet with its parts
# joined by material, so each material becomes one MeshPart named P<n>, plus a JSON sidecar that
# says how Studio paints each part: colour and a Roblox material (Neon for glow, Glass with
# transparency for domes and crystals, CrackedLava for a meteor's molten shell, SmoothPlastic with
# reflectance for gloss and metal). A preview step, not the final game pipeline: patterned finishes
# are flat and the effects are geometry, not particles.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/export_robo_roblox.py -- <outdir> <kind id>:<tier 0..4 | m0..m4> ...

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
    return channel * 12.92 if channel <= 0.0031308 else 1.055 * channel ** (1 / 2.4) - 0.055


def paint_of(mat):
    """How Studio paints a part of this material."""
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    inputs = bsdf.inputs
    base = list(inputs["Base Color"].default_value)[:3]
    emission = list(inputs["Emission Color"].default_value)[:3]
    strength = inputs["Emission Strength"].default_value
    alpha = inputs["Alpha"].default_value
    if mat.name.startswith("Meteor"):
        return {"material": "CrackedLava", "color": [0.35, 0.12, 0.05]}
    if strength >= 1.0 and max(emission) > 0.2:
        return {"material": "Neon", "color": [srgb(c) for c in emission]}
    if alpha < 0.99:
        return {"material": "Glass", "color": [srgb(c) for c in base], "transparency": round(1 - alpha, 2)}
    if inputs["Transmission Weight"].default_value >= 0.5:
        return {"material": "Glass", "color": [srgb(c) for c in base], "transparency": 0.45}
    metallic = inputs["Metallic"].default_value
    if metallic >= 0.5:
        return {"material": "SmoothPlastic", "color": [srgb(c) for c in base], "reflectance": 0.35}
    reflectance = 0.12 if inputs["Roughness"].default_value < 0.25 else 0.02
    return {"material": "SmoothPlastic", "color": [srgb(c) for c in base], "reflectance": reflectance}


def join_by_material():
    """Real meshes with modifiers applied, then one object per material."""
    for obj in list(bpy.data.objects):
        if obj.type not in ("MESH", "CURVE", "META", "FONT"):
            bpy.data.objects.remove(obj)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.convert(target="MESH")
    groups = {}
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj.data.materials and obj.data.materials[0]:
            groups.setdefault(obj.data.materials[0].name, []).append(obj)
    paints = {}
    for index, (name, objects) in enumerate(sorted(groups.items())):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = joined.data.name = f"P{index}"
        paints[joined.name] = paint_of(bpy.data.materials[name])
    return paints


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    kinds = {kind[0]: kind for kind in robo_kinds.KINDS}
    for spec in SPECS:
        kind_id, variant = spec.split(":")
        meteor = variant.startswith("m")
        tier = int(variant.lstrip("m"))
        bpy.ops.wm.read_factory_settings(use_empty=True)
        robo_kinds.build(kinds[kind_id], tier, 0.0, 0.0, meteor)
        paints = join_by_material()
        name = f"{kind_id}-{variant}"
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, name + ".glb"), export_format="GLB", use_selection=True,
                                  export_apply=True, export_yup=True, export_texcoords=False, export_materials="NONE")
        with open(os.path.join(OUT_DIR, name + ".json"), "w", encoding="utf-8") as file:
            json.dump(paints, file)
        print("Exported", name, len(paints), "parts")


main()
