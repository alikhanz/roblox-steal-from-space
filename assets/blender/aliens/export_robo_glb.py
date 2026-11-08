# Exports the robot pets (decisions 074, 075) as GLB files for the 3D viewer page: every kind in
# robo_kinds.py in each tier, plain and as a meteor: <outdir>/<kind id>-<0..4>.glb and -m<0..4>.glb.
#
# glTF carries plain materials only (colour, gloss, metal, glass, glow), so the noise-patterned
# finishes (frost, scuffed ceramic, nebula, molten rock) are swapped for flat look-alikes here;
# round shapes are divided more coarsely than in the renders to keep hundreds of files small.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/export_robo_glb.py -- <outdir> [kind id ...]

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import real  # noqa: E402
import robo  # noqa: E402
import robo_kinds  # noqa: E402
from mathutils import noise  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = ARGS[0] if ARGS else "out/robo"
ONLY = set(ARGS[1:])
robo.DETAIL = 0.6
CRUST_FLAT = (0.07, 0.045, 0.035)


def _flat(name, color, roughness, metallic=0.0, coat=0.0, emission=None, strength=0.0):
    mat, nodes, links, bsdf = real._principled(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Coat Weight"].default_value = coat
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    mat.diffuse_color = (*color, 1.0)
    return mat


real.frost = lambda name, color, glow=0.0: _flat(name, color, 0.3, coat=0.6, emission=color if glow else None, strength=glow)
real.chitin = lambda name, color, dark, metallic=0.25: _flat(name, tuple((a + b) / 2 for a, b in zip(color, dark)), 0.32, metallic, 0.8)
real.nebula = lambda name, deep, mid, bright, star_strength=6.0: _flat(name, mid, 0.2, emission=mid, strength=1.2)
real.molten = lambda name: _flat(name, CRUST_FLAT, 0.6)
real.armor = lambda name, color: _flat(name, color, 0.5)
# The molten parts are recoloured with lava cracks just before export (lava_cracks).


CRUST = (0.07, 0.045, 0.035)
LAVA = (1.0, 0.33, 0.04)


def lava_cracks():
    """glTF has no procedural cracks, so a meteor's molten parts get them as vertex colours: glowing
    lava along the edges of Voronoi cells over dark crust (the renders draw the same pattern)."""
    mat, nodes, links, bsdf = real._principled("MeteorLava")
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "Lava"
    links.new(attribute.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Emission Color"].default_value = (*LAVA, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 0.25
    for obj in bpy.data.objects:
        if obj.type != "MESH" or not obj.data.materials or not obj.data.materials[0].name.startswith("Meteor"):
            continue
        mesh = obj.data
        colours = mesh.color_attributes.new("Lava", "FLOAT_COLOR", "POINT")
        world = obj.matrix_world
        for vertex in mesh.vertices:
            distances, _ = noise.voronoi(world @ vertex.co * 3.0)
            edge = distances[1] - distances[0]
            heat = max(0.0, 1.0 - edge / 0.12)
            colours.data[vertex.index].color = (*(c + (l - c) * heat for c, l in zip(CRUST, LAVA)), 1.0)
        mesh.materials[0] = mat


def tame_glow():
    """Renders keep glow strong for bloom; in a web viewer glTF's emissive strength above 1 burns
    every glowing part (wings, rays, rings) to white and hides its colour, so it is capped here."""
    for mat in bpy.data.materials:
        bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
        if bsdf and bsdf.inputs["Emission Strength"].default_value > 1.0:
            bsdf.inputs["Emission Strength"].default_value = 1.0


def export(path):
    lava_cracks()
    tame_glow()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_texcoords=False)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for kind in robo_kinds.KINDS:
        if ONLY and kind[0] not in ONLY:
            continue
        for tier in range(5):
            for meteor in (False, True):
                bpy.ops.wm.read_factory_settings(use_empty=True)
                robo_kinds.build(kind, tier, 0.0, 0.0, meteor)
                export(os.path.join(OUT_DIR, f"{kind[0]}-{'m' if meteor else ''}{tier}.glb"))
        print("Exported", kind[0])


main()
