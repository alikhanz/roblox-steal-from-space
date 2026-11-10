# Exports the adult guardians for Roblox (docs/plans/GUARDIANS.md, step 2): all posts, or the ones
# named, in one GLB, a row of guardians, the way the pets are packed (export_robo_roblox.py, whose
# joining and paint codes this reuses): parts join by role and look, so each guardian is a few dozen
# MeshParts; what moves (arms, legs, jaws, fins, wings, flukes, rotors, the hunters' flock) keeps a
# role of its own with a hinge marker; effect stand-ins (role fx) are left out. Everything the game
# needs rides in the node names:
#   <Post>|<role>_<n>|<paint code>          a part;
#   <Post>|meta1|zone|family|signature      and
#   <Post>|meta2|glow|core|shell|eyes       the guardian (tiny marker nodes; colours as sRGB hex).
# <Post> is the GuardianConfig post id (the main kind's id, capitalised).
#
# A guardian is drawn at the size of a pet's model (growth 1, the pet_scale of its family): the game
# scales it to its post (GuardianLooks).
#
# Prints a budget line per guardian (parts and triangles) and flags those over the phone budget.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/guardians/export_guardians_roblox.py -- <outdir> [post ...]

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))
sys.path.insert(0, HERE)

import adults  # noqa: E402
import bpy  # noqa: E402
import export_robo_roblox as pets  # noqa: E402
import robo  # noqa: E402
import robo_kinds  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = ARGS[0] if ARGS else "out/guardians"
ONLY = set(ARGS[1:])

# Coarser than a pet (0.8): a guardian is seen from farther, and 132 of them stand on the map.
robo.DETAIL = 0.5
# The game paints these by name: the eyes by the guardian's state, the throat brighter in a chase.
pets.SPECIAL_SOURCES = pets.SPECIAL_SOURCES | {"GuardianEye", "Maw"}


def bake_colour(obj, rgb):
    """The object's colour in its vertices as Roblox reads it: Roblox takes glTF COLOR_0 as sRGB
    numbers, so the sRGB numbers go into the linear setter and the GLB holds them unchanged (the
    pets' `color_srgb` bake arrives darker and richer than its Color3; BLENDER_ROBLOX.md, section 2.
    The pets keep theirs: their look was approved as it shows)."""
    attribute = obj.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color = (*rgb, 1.0)
    obj.data.color_attributes.active_color = attribute


pets.bake_colour = bake_colour
# The phone budget per guardian (plan, step 2).
MAX_PARTS = 40
MAX_TRIANGLES = 8000
# Thinning aims a little under the budget, and never below this share of a mesh (it breaks shapes).
TARGET_TRIANGLES = 7500
MIN_RATIO = 0.2
SMALL_PART = 150
SPACING = 14.0


def post_id(kind):
    return kind[0][0].upper() + kind[0][1:]


def hex_of(colours, key):
    """A colour of the theme as sRGB hex: the marker names must stay short."""
    return "".join(f"{round(c * 255):02x}" for c in pets.colour(colours[key]))


def triangles(obj):
    return sum(len(polygon.vertices) - 2 for polygon in obj.data.polygons)


def fit_budget(objects):
    """Thins the bigger meshes (collapse decimation, one ratio for all) until the guardian fits
    TARGET_TRIANGLES; parts under SMALL_PART triangles (eyes, spikes, rings) are left alone."""
    total = sum(triangles(obj) for obj in objects)
    if total <= TARGET_TRIANGLES:
        return
    big = [obj for obj in objects if triangles(obj) > SMALL_PART]
    fixed = total - sum(triangles(obj) for obj in big)
    ratio = max(MIN_RATIO, (TARGET_TRIANGLES - fixed) / (total - fixed))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in big:
        modifier = obj.modifiers.new("Decimate", "DECIMATE")
        modifier.ratio = ratio
        depsgraph.update()
        thinned = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
        obj.modifiers.remove(modifier)
        obj.data = thinned


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    packed = bpy.data.collections.new("Packed")
    bpy.context.scene.collection.children.link(packed)
    posts = [k for k in robo_kinds.KINDS if k[8] == 0 and (not ONLY or post_id(k) in ONLY or k[0] in ONLY)]
    over = []
    for index, kind in enumerate(posts):
        post = post_id(kind)
        colours = robo.theme(kind[3], kind[4])["colours"]
        adults.build(kind, 0.0, 0.0, growth=1.0)
        parts = pets.join_by_role()
        fit_budget([obj for obj in bpy.context.view_layer.objects if obj.type == "MESH" and obj.name in parts and not obj.name.startswith("hinge")])
        finished = []
        count, tris = 0, 0
        for obj in list(bpy.context.view_layer.objects):
            if obj.type != "MESH":
                continue
            paint = parts.get(obj.name)
            if paint is None:
                bpy.data.objects.remove(obj)
                continue
            if not obj.name.startswith("hinge"):
                count += 1
                tris += triangles(obj)
            obj.name = obj.data.name = f"{post}|{obj.name}|{pets.paint_code(paint)}"
            finished.append(obj)
        signature = "+".join(part.__name__ for part in kind[6])
        finished.append(pets.marker(f"{post}|meta1|{kind[3]}|{kind[2]}|{signature}", (0, 0, -1)))
        finished.append(pets.marker(f"{post}|meta2|{hex_of(colours, 'glow')}|{hex_of(colours, 'core')}|{hex_of(colours, 'shell')}|{hex_of(colours, 'eyes')}", (0, 0, -1)))
        for obj in finished:
            if len(obj.name) > 62:
                raise ValueError(f"name too long for Blender: {obj.name}")
            obj.location.x += index * SPACING
            for collection in list(obj.users_collection):
                collection.objects.unlink(obj)
            packed.objects.link(obj)
        # Finished guardians leave the view layer, so the next build and join leave them alone.
        bpy.context.view_layer.layer_collection.children["Packed"].exclude = True
        flag = "" if count <= MAX_PARTS and tris <= MAX_TRIANGLES else "  OVER BUDGET"
        if flag:
            over.append(post)
        print(f"Budget {post:14} {count:3} parts {tris:6} triangles{flag}", flush=True)
    bpy.context.view_layer.layer_collection.children["Packed"].exclude = False
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT_DIR, "pack-guardians.glb")
    pets.export_glb(path)
    print("Packed", len(posts), "guardians,", len(bpy.context.selected_objects), "nodes,", os.path.getsize(path), "bytes ->", path)
    if over:
        print("Over budget:", ", ".join(over))


if __name__ == "__main__":
    main()
