# Exports robot pets for a look in Roblox Studio (decision 074): one GLB per pet and a JSON sidecar.
#
# Parts are joined by role and look (robo.py tags every part with its role; a look is the paint code,
# see KEEP_ROLES for what stays one part per material), so each becomes one MeshPart named
# <role>_<n>: the game can move the ones that move (wings, rotor, drones, orbits,
# rays) and paint each from the sidecar (colour and a Roblox material: Neon for glow, Glass for
# domes and crystals, CrackedLava for a meteor's molten shell, SmoothPlastic for the rest). Parts
# that only stand in for effects (role "fx": motes, sparkles, embers, comet tails) are left out:
# the game plays particles there instead. The sidecar also names the pet (kind, zone, family, tier,
# meteor, signature parts) and its colours, so the game can pick the particles.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/export_robo_roblox.py -- <outdir> <kind id>:<0..4 | m0..m4> ...

import colorsys
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
from mathutils import Vector  # noqa: E402

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


# Merging (docs/plans/ALIEN_MODELS.md, 2б): parts of one role that look the same in game (one paint
# code) become one mesh, even when Blender gave them copies of a material ("Seam.001", "Seam.002"):
# every MeshPart is a mesh the player downloads and a part the client moves. Kept as they were (one
# object per role and material) are the parts the game reads one by one:
#   * roles whose parts' positions it averages or takes one by one: the rotor (it spins about its
#     parts' middle), a swarm's little drones (they fly round from theirs), the hinge markers (the
#     pivot is the part), the rune circle (each piece turns about itself), the candle flames;
KEEP_ROLES = {"rotor", "halo", "flame"}
KEEP_ROLE_PREFIXES = ("hinge",)
#   * parts that each stand for something: the eyes (each blinks), a slime's dome (its jelly floor),
#     the hidden flame and ray stand-ins and jetpack flames (particles play from each), the wings'
#     membranes; and a meteor's lava (its own UVs).
KEEP_SOURCES = {"EyeLight", "Dome", "Jet", "Flame", "FlameCore", "Tongue", "Ray", "RayShort"}


def keeps_apart(role, material):
    source = material.name.split(".")[0]
    return (
        role in KEEP_ROLES
        or role.startswith(KEEP_ROLE_PREFIXES)
        or (role.startswith("drone") and role[5:].isdigit())
        or source in KEEP_SOURCES
        or source.endswith("Wing")
        or material.name.startswith("Meteor")
    )


# Baking (docs/plans/ALIEN_MODELS.md, 2в): Roblox draws a mesh's vertex colours (glTF COLOR_0) times
# the part's Color, on SmoothPlastic, Neon, Glass and the PetMetal variant alike (tested in Studio,
# 2026-11-10). So static parts of one role and one class of material (plastic of one reflectance,
# metal, Neon, glass of one transparency) join into one mesh whatever their colours: each keeps its
# colour in its vertices, the game paints the joined part white (paint code source "Baked").
# The colour baked is the one the game gives the paint (AlienDress.paint, kept in step by hand):
# plastic and metal a touch richer, gold its own bright gold.
BAKED = "Baked"
# How baked parts of one role join (the guardians' export sets it; MERGE_MODES):
#   "split" - one part per role, material class and reflectance; a part across a slime's jelly floor
#             stays alone (the look the pets and guardians shipped with);
#   "paint" - the same, but the parts across the floor join one another (step A: the look stays);
#   "class" - one part per role and material class (plastic, Neon, glass): reflectances join, the
#             group takes the reflectance most of its surface had (step B: some shine is lost).
MERGE = "split"
MERGE_MODES = ("split", "paint", "class")
# Materials AlienDress.paint treats by name (crystals, auras, the aurora's ribbons, the nebula): they
# keep their own paint.
SPECIAL_SOURCES = KEEP_SOURCES | {
    "Shard", "IceSpike", "Icicle", "Fringe", "Spout", "Bubble", "Brood",
    "Hover", "Smoke",
    "Aurora",
    "Galaxy",
}
GOLD_SOURCES = {"Gold", "GoldArmour", "Crown", "Circlet", "Badge"}
GOLD = (255 / 255, 190 / 255, 45 / 255)
# Roles the game colours itself (the core from the pet's colours, the wings in its accent) or hides.
OWN_COLOUR_ROLES = {"core", "wingL", "wingR", "ring", "rays"}


def boost(rgb, saturation, value):
    """Color3:ToHSV, scaled and clamped, back (AlienDress.boost)."""
    h, s, v = colorsys.rgb_to_hsv(*rgb)
    return colorsys.hsv_to_rgb(h, min(1.0, s * saturation), min(1.0, v * value))


def baked(role, paint):
    """The class of look a part joins others of its role in, and the colour (sRGB, 0..1) the game would
    give it; None for a part that keeps its own paint."""
    source = paint["source"]
    if role in OWN_COLOUR_ROLES or source in SPECIAL_SOURCES or source.endswith("Wing"):
        return None
    # The paint code's rounded colour: what the game reads.
    rgb = tuple(round(c * 255) / 255 for c in paint["color"])
    material = paint["material"]
    if material == "SmoothPlastic" and paint.get("metal"):
        return ("S", 0, paint["reflectance"]), GOLD if source in GOLD_SOURCES else boost(rgb, 1.15, 1.05)
    if material == "SmoothPlastic":
        return ("S", 0, paint["reflectance"]), boost(rgb, 1.25, 1.12)
    if material == "Neon":
        return ("N", 0, 0), rgb
    if material == "Glass":
        return ("G", paint["transparency"], 0), rgb
    return None


def bake_colour(obj, rgb):
    """The object's colour in its vertices (sRGB in Blender, linear in the GLB as glTF wants)."""
    attribute = obj.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color_srgb = (*rgb, 1.0)
    obj.data.color_attributes.active_color = attribute


def z_span(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return min(c.z for c in corners), max(c.z for c in corners)


def jelly_floor(objects):
    """A slime's jelly floor, as the game finds it (AlienMotionController: a little above the bottom
    of its dome): what stands above it squashes with the jelly, so a merge never spans it."""
    for obj in objects:
        material = obj.data.materials[0]
        if material.name.split(".")[0] == "Dome":
            low, high = z_span(obj)
            return (low + high) / 2 - (high - low) * 0.3
    return None


def join_by_role():
    """Real meshes with modifiers applied, effect stand-ins dropped, one object per role and look
    (see KEEP_ROLES for what stays apart). Works on the objects of the view layer only (a pack keeps
    finished pets out of it)."""
    for obj in list(bpy.context.view_layer.objects):
        if obj.type not in ("MESH", "CURVE", "META", "FONT") or obj.get("role") == "fx":
            bpy.data.objects.remove(obj)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    roles = {obj.name: obj.get("role", "body") for obj in bpy.context.selected_objects}
    bpy.ops.object.convert(target="MESH")
    lava_uvs()
    meshes = [obj for obj in bpy.context.view_layer.objects if obj.type == "MESH" and obj.data.materials and obj.data.materials[0]]
    floor = jelly_floor(meshes)
    assert MERGE in MERGE_MODES, f"unknown merge mode {MERGE}"
    groups = {}
    bakes = {}
    # Surface area by reflectance, per baked group ("class" mode picks the most common).
    shine = {}
    for obj in meshes:
        role = roles.get(obj.name, obj.get("role", "body"))
        material = obj.data.materials[0]
        if keeps_apart(role, material):
            look = "m:" + material.name
        else:
            paint = {**paint_of(material), "source": material.name.split(".")[0]}
            bake = baked(role, paint)
            if bake:
                look_class, rgb = bake
                if MERGE == "class":
                    look = "b:" + f"{look_class[1]:g}" + look_class[0]
                else:
                    look = "b:" + ",".join(f"{value:g}" for value in look_class[1:]) + look_class[0]
                bake_colour(obj, rgb)
            else:
                look = "p:" + paint_code(paint)
            if floor is not None:
                low, high = z_span(obj)
                across = "|" + obj.name if MERGE == "split" else "|across"
                look += "|above" if low > floor else "|below" if high < floor else across
            if bake:
                area = sum(polygon.area for polygon in obj.data.polygons) * max(obj.scale) ** 2
                key = (role, look)
                shine.setdefault(key, {})
                reflectance = look_class[2]
                shine[key][reflectance] = shine[key].get(reflectance, 0.0) + area
        groups.setdefault((role, look), []).append(obj)
    parts = {}
    for index, ((role, look), objects) in enumerate(sorted(groups.items())):
        first = objects[0].data.materials[0]
        material = first.name
        if look.startswith("b:"):
            bakes[f"{role}_{index}"] = {**paint_of(first), "color": [1.0, 1.0, 1.0], "source": BAKED}
            areas = shine.get((role, look))
            if MERGE == "class" and areas and bakes[f"{role}_{index}"]["material"] == "SmoothPlastic":
                bakes[f"{role}_{index}"]["reflectance"] = max(areas, key=areas.get)
        # Copies of one look share the first one's material, so the joined mesh is one primitive.
        for obj in objects[1:]:
            own = obj.data.materials[0]
            for slot, used in enumerate(obj.data.materials):
                if used == own:
                    obj.data.materials[slot] = first
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = joined.data.name = f"{role}_{index}"
        if look.startswith("b:"):
            joined.data.color_attributes.active_color = joined.data.color_attributes["Col"]
        # The Blender material's name goes along, so the game (and a check of the render against
        # the game) knows what a part is, not only its colour.
        parts[joined.name] = bakes.get(joined.name) or {**paint_of(bpy.data.materials[material]), "source": material.split(".")[0]}
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


def export_glb(path):
    """The selection as a GLB: geometry, the lava's UVs and the baked vertex colours, no materials (the
    game paints from the paint codes in the names)."""
    options = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                   export_texcoords=True, export_materials="NONE")
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)


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
    export_glb(path)
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
        export_glb(os.path.join(OUT_DIR, name + ".glb"))
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


if __name__ == "__main__":
    main()
