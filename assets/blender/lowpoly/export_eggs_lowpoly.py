# Exports the low-poly egg kit (decision 122): one node per shape of lowpoly_eggs.py, about the
# egg's centre (the origin), with the `Centre` speck the game measures the others from
# (World/EggKit). No colours: the game paints every part (World/EggModel).
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/lowpoly/export_eggs_lowpoly.py -- <outdir>
# Writes <outdir>/egg-kit-lowpoly.glb and prints each shape's triangles and each egg's budget.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bmesh  # noqa: E402
import bpy  # noqa: E402
import lowpoly_eggs as eggs  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/egg_kit_lowpoly")

# What each egg wears (World/EggModel.piecesOf; keep in step): the rarity's add-ons, then the
# finish's. A special egg (meteor, star) wears no tip: its flame or star stands there.
TIERS = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]


def worn(rarity, finish):
    tier = TIERS.index(rarity)
    pieces = ["GemShell", "GemGirdle"]
    if tier >= 1 and finish == "Normal":
        pieces.append("GemTip")
    if tier >= 2:
        pieces.append("GemFins")
    if tier >= 3:
        pieces.append("GemOrbit")
    if tier >= 4:
        pieces.append("GemCrown")
    if finish == "Meteor":
        pieces += ["MeteorCracks", "MeteorFlame"]
    elif finish == "Star":
        pieces += ["StarTop", "StarDots"]
    return pieces


def shape(name, fill):
    bm = bmesh.new()
    fill(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces:
        face.smooth = False
    data = bpy.data.meshes.new(name)
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    data.calc_loop_triangles()
    return obj, len(data.loop_triangles)


def centre():
    s = 0.02
    data = bpy.data.meshes.new("Centre")
    data.from_pydata([(-s, -s, -s), (s, -s, -s), (0, s, -s), (0, 0, s)], [], [(0, 2, 1), (0, 1, 3), (1, 2, 3), (2, 0, 3)])
    obj = bpy.data.objects.new("Centre", data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    objects, triangles = [], {}
    for name, fill in eggs.SHAPES.items():
        obj, count = shape(name, fill)
        objects.append(obj)
        triangles[name] = count
    objects.append(centre())
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in objects)
    path = os.path.join(OUT_DIR, "egg-kit-lowpoly.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_texcoords=False, export_normals=True, export_materials="NONE")
    print("Wrote", path, len(objects), "nodes", os.path.getsize(path), "bytes")
    print("Shapes:", ", ".join(f"{name} {count}" for name, count in triangles.items()))
    tops = {obj.name: max(v.co.z for v in obj.data.vertices) for obj in objects}
    for finish in ("Normal", "Meteor", "Star"):
        for rarity in TIERS:
            pieces = worn(rarity, finish)
            print(f"  {finish:6} {rarity:9} {sum(triangles[p] for p in pieces):4} triangles in {len(pieces)} parts")
        # EggLooks.reachOf keeps these: how high an egg of each kind reaches over its centre.
        print(f"  {finish} reaches {max(tops[p] for p in worn('Legendary', finish) + worn('Uncommon', finish)):.2f}")


if __name__ == "__main__":
    main()
