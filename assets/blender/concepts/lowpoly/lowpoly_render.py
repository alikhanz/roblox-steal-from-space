# Concept (low-poly pets): renders the comparison cells. Each pet is drawn by itself with one fixed
# camera and light rig, near (a big cell) and far (a phone-size thumbnail), today's robot pet and the
# same kind and tier in each low-poly style. Also counts each style's pets in all ten variants of a
# kind: triangles, parts, meshes per pet, and the meshes all of them share.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_render.py -- <outdir> [style ...]
# Styles: today faceted toy sharp (all by default). Writes <outdir>/cells/*.png and <outdir>/<style>.json.

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "..", "aliens"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "out/lowpoly"
STYLES = ARGS[1:] or ["today", "faceted", "toy", "sharp"]
KINDS = ["slimeWarden", "crabDrone", "spaceWhale"]
SHOWN = ["0", "3", "4"]
VARIANTS = ["0", "1", "2", "3", "4", "m0", "m1", "m2", "m3", "m4"]
NEAR, FAR = 560, 72
# The camera looks at the pet from the front left and a little above; it backs off as the pet grows
# (robo.GROWTH), so one tier is framed alike in every style.
TARGET = Vector((0, 0.25, 1.35))
VIEW = Vector((-3.6, -7.4, 2.4))
GROWTH = [0.74, 0.86, 1.0, 1.14, 1.3]
# Today's parts the game hides (AlienDress: stand-ins play particles, rings and rays are hidden,
# hinge and dust markers become points).
HIDDEN_SOURCES = {"Flame", "FlameCore", "Tongue", "Ray", "RayShort", "Jet"}
HIDDEN_ROLES = ("hinge", "dust", "ring", "rays", "flame")


def stage(tier):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 48), ("use_shadows", True)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.4
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    dark = nodes.get("Background")
    dark.inputs["Color"].default_value = (0.012, 0.016, 0.04, 1.0)
    sky = nodes.new("ShaderNodeBackground")
    sky.inputs["Strength"].default_value = 0.4
    texture = nodes.new("ShaderNodeTexSky")
    links.new(texture.outputs["Color"], sky.inputs["Color"])
    path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(sky.outputs["Background"], mix.inputs[1])
    links.new(dark.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], nodes.get("World Output").inputs["Surface"])

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (TARGET - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (-6, -7, 9), 1500, 5, (1.0, 0.97, 0.92))
    area("Fill", (7, -6, 2.5), 420, 7, (0.75, 0.85, 1.0))
    area("Rim", (1, 8, 6), 1800, 8, (0.55, 0.65, 1.0))
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 50
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    # A floor disc so the pet stands somewhere (a pet place on the island).
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=2.4, depth=0.1, location=(0, 0, -0.05))
    floor = bpy.context.active_object
    floor.name = "Floor"
    mat = bpy.data.materials.new("FloorMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.05, 0.06, 0.09, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.6
    floor.data.materials.append(mat)
    frame(tier)


def frame(tier):
    """Camera and floor for a tier: the legendary, with its star and wings, a little further back."""
    scene = bpy.context.scene
    g = GROWTH[tier] if tier < 4 else 1.6
    target = TARGET * g
    scene.camera.location = target + VIEW * g
    scene.camera.rotation_euler = (target - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.data.objects["Floor"].scale = (GROWTH[tier], GROWTH[tier], 1.0)


def shoot(name):
    scene = bpy.context.scene
    os.makedirs(os.path.join(OUT, "cells"), exist_ok=True)
    for size, suffix in ((NEAR, "near"), (FAR, "far")):
        scene.render.resolution_x = scene.render.resolution_y = size
        scene.render.filepath = os.path.join(OUT, "cells", f"{name}-{suffix}.png")
        bpy.ops.render.render(write_still=True)


def today(kind_id, variant):
    import export_robo_roblox  # noqa: F401  (the game's export settings: flat finishes, DETAIL 0.8)
    import robo_kinds

    bpy.ops.wm.read_factory_settings(use_empty=True)
    stage(int(variant.lstrip("m")))
    kind = next(k for k in robo_kinds.KINDS if k[0] == kind_id)
    robo_kinds.build(kind, int(variant.lstrip("m")), 0.0, 0.0, variant.startswith("m"))
    for obj in list(bpy.data.objects):
        if obj.get("role") == "fx":
            bpy.data.objects.remove(obj)
            continue
        material = obj.data.materials[0].name.split(".")[0] if getattr(obj, "data", None) is not None and getattr(obj.data, "materials", None) and obj.data.materials[0] else ""
        if material in HIDDEN_SOURCES or obj.get("role", "").startswith(HIDDEN_ROLES):
            obj.hide_render = True
    shoot(f"{kind_id}-{variant}-today")


def styled(style):
    import lowpoly_kit as kit
    import lowpoly_pets as pets

    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit._MATERIALS.clear()
    stage(0)
    library = kit.Library(style)
    results = []
    collections = {}
    for kind_id in KINDS:
        for variant in VARIANTS:
            collection = bpy.data.collections.new(f"{kind_id}-{variant}")
            bpy.context.scene.collection.children.link(collection)
            collections[(kind_id, variant)] = collection
            pet = pets.build(pets.kind(kind_id), int(variant.lstrip("m")), style, library, variant.startswith("m"), collection)
            stats = pet.stats()
            # Merged per kind: the static parts of one paint joined into one mesh of the kind (fewer
            # parts, a few meshes of its own); moving, blinking and outfit parts stay as they are.
            static = {}
            for obj in pet.objects:
                if obj["role"] == "body" and not obj.data.name.split(":")[1] in ("crown", "gems", "tank", "star", "wing", "wing_edge"):
                    static.setdefault(obj.material_slots[0].material.name, []).append(obj)
            merged_parts = stats["parts"] - sum(len(group) for group in static.values()) + len(static)
            results.append({"kind": kind_id, "variant": variant, "style": style, **stats, "mergedParts": merged_parts, "mergedGroups": len(static)})
            print(f"STYLE {style} {kind_id}-{variant}: {stats['triangles']} tris, {stats['parts']} parts ({merged_parts} merged), {len(stats['meshes'])} meshes")
    for (kind_id, variant), collection in collections.items():
        collection.hide_render = True
    for (kind_id, variant), collection in collections.items():
        if variant in SHOWN:
            collection.hide_render = False
            frame(int(variant))
            shoot(f"{kind_id}-{variant}-{style}")
            collection.hide_render = True
    library_meshes = {name: len(mesh.loop_triangles) if mesh.calc_loop_triangles() is None else 0 for name, mesh in library.meshes.items()}
    with open(os.path.join(OUT, f"{style}.json"), "w", encoding="utf-8") as file:
        json.dump({"style": style, "pets": results, "library": library_meshes}, file, indent=1)
    print(f"LIBRARY {style}: {len(library.meshes)} meshes", library_meshes)


def main():
    for style in STYLES:
        if style == "today":
            for kind_id in KINDS:
                for variant in SHOWN:
                    today(kind_id, variant)
        else:
            styled(style)


if __name__ == "__main__":
    main()
