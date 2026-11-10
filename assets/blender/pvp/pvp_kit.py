# The PvP abilities' kit of meshes (brief docs/design/screens/pvp-abilities.md). The user chose
# concept A for both (concept_pvp.py, docs/design/concepts/pvp/; 2026-11-10): a harpoon hook on a
# cable out of a wrist launcher, and a "gyroscope" gravity bomb - a dark core in two orbiting rings
# that ends in a ring wave as wide as the blast.
#
# The game draws them on every client (World/HarpoonVisual, World/BombVisual) from
# ReplicatedStorage.PvpKit. Built for phones (docs/design/BLENDER_ROBLOX.md, sections 3 and 7): one
# piece per material class, colours baked in the vertex colours (glTF COLOR_0, written as sRGB
# numbers), everything that glows a Neon piece of its own, white here and coloured by the game
# (PvpLooks):
#   HookOrigin, HookBody, HookGlow, ClawsOpen, ClawsClosed, HookBack - the hook about the point
#        its claws close on (HookOrigin), pointing -Y: pearl shaft, steel collar and hub; its
#        magnet band; the three claws open (in flight) and closed (holding); where the cable
#        meets its back (HookBack);
#   LauncherOrigin, LauncherBody, LauncherGlow, Muzzle - the wrist launcher about the hand
#        (LauncherOrigin), pointing -Y: steel tube; its muzzle ring; the muzzle (Muzzle);
#   BombOrigin, BombBody, BombGlow, BombLight - the bomb's core about its centre: navy shell with
#        steel caps; its belt; the light that blinks;
#   RingOrigin, Ring - a thin ring of radius 1 round +Z (flat on the ground in Roblox): the bomb's
#        orbits, its wave and the hook's grab flash, sized by the game.
# The specks (*Origin, HookBack, Muzzle) are tiny cubes the game measures from; insertion into
# Studio turns the whole kit about Y, which offsets from the specks don't mind. Directions: front
# -Y here (-Z, the look vector, in Roblox), up +Z.
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/pvp/pvp_kit.py -- <outdir> [--sheet]
# Writes <outdir>/pvp-kit.glb; with --sheet also <outdir>/pvp-kit.png, the pieces as the game
# dresses them.

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SHEET = "--sheet" in ARGS
ARGS = [a for a in ARGS if a != "--sheet"]
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "out/pvp_kit")

# Where the groups stand apart (only for looking at the kit; the game measures from specks).
HOOK_AT = Vector((0, 0, 0))
LAUNCHER_AT = Vector((5, 0, 0))
BOMB_AT = Vector((10, 0, 0))
RING_AT = Vector((15, 0, 0))

# The hook's size, studs (PvpLooks.HARPOON reads it from the kit): about 3 long, so it reads at
# 20-50 studs on a phone.
HOOK_LENGTH = 3.0
# The bomb's core radius and its belt.
BOMB_RADIUS = 1.1

# Baked colours, sRGB 0..255 (the station's pearl and steel, as the eggs, kiosks and serpent).
PEARL = (236, 239, 245)
STEEL = (150, 158, 185)
DARK = (38, 40, 54)
NAVY = (22, 28, 58)
TIP = (120, 225, 255)
WHITE = (255, 255, 255)


# --- Pieces --------------------------------------------------------------------------------------


def paint(obj, rgb):
    mesh = obj.data
    attribute = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for item in attribute.data:
        item.color = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0)
    mesh.color_attributes.active_color = attribute
    return obj


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def apply(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def join(name, parts, origin):
    """One piece of `parts`, its mesh about `origin` (its object placed there)."""
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = obj.data.name = name
    apply(obj)
    obj.data.transform(Matrix.Translation(-origin))
    obj.location = origin
    return obj


def turn_to(direction):
    return Vector(direction).to_track_quat("Z", "Y").to_euler()


def ball(location, radius, rgb, segs=20, rings=10, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.scale = scale
    return paint(smooth(obj), rgb)


def rod(a, b, radius, rgb, radius2=None, vertices=16):
    a, b = Vector(a), Vector(b)
    depth = (b - a).length
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(a + b) / 2, rotation=turn_to(b - a))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius2, depth=depth, location=(a + b) / 2,
                                        rotation=turn_to(b - a))
    return paint(smooth(bpy.context.active_object), rgb)


def ring(location, major, minor, rgb, axis, segments=32, sides=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segments, minor_segments=sides,
                                     location=location, rotation=turn_to(axis))
    return paint(smooth(bpy.context.active_object), rgb)


def speck(name, location):
    bpy.ops.mesh.primitive_cube_add(size=0.05, location=location)
    obj = bpy.context.active_object
    obj.name = obj.data.name = name
    paint(obj, WHITE)
    apply(obj)
    obj.data.transform(Matrix.Translation(-Vector(location)))
    obj.location = location
    return obj


# --- The hook ------------------------------------------------------------------------------------

FORWARD = Vector((0, -1, 0))
SIDE = Vector((1, 0, 0))
UP = Vector((0, 0, 1))


def claws(o, k, spread, bend):
    """Three claws round the hook's axis: from the hub out and forward, curling in at the tip."""
    parts = []
    for i in range(3):
        angle = i * 2 * math.pi / 3 + math.pi / 2
        radial = SIDE * math.cos(angle) + UP * math.sin(angle)
        root = o - FORWARD * 0.55 * k + radial * 0.22 * k
        knee = o - FORWARD * 0.05 * k + radial * spread * k
        tip = o + FORWARD * 0.4 * k + radial * (spread - bend) * k
        parts.append(rod(root, knee, 0.1 * k, STEEL, radius2=0.08 * k, vertices=8))
        parts.append(ball(knee, 0.08 * k, STEEL, segs=8, rings=4))
        parts.append(rod(knee, tip, 0.08 * k, STEEL, radius2=0.03 * k, vertices=8))
        parts.append(ball(tip, 0.07 * k, TIP, segs=8, rings=4))
    return parts


def hook():
    o = HOOK_AT
    k = HOOK_LENGTH / 3.0
    back = o - FORWARD * 2.6 * k
    body = [
        rod(back, o - FORWARD * 0.95 * k, 0.17 * k, PEARL),
        ball(back, 0.2 * k, STEEL, segs=12, rings=6),
        rod(o - FORWARD * 1.2 * k, o - FORWARD * 0.85 * k, 0.32 * k, STEEL, vertices=20),
        rod(o - FORWARD * 0.65 * k, o - FORWARD * 0.45 * k, 0.3 * k, STEEL, radius2=0.2 * k, vertices=20),
    ]
    glow = [rod(o - FORWARD * 0.85 * k, o - FORWARD * 0.65 * k, 0.29 * k, WHITE, vertices=20)]
    opened = claws(o, k, spread=0.62, bend=0.12)
    closed = claws(o, k, spread=0.42, bend=0.36)
    return [
        speck("HookOrigin", o),
        join("HookBody", body, o),
        join("HookGlow", glow, o),
        join("ClawsOpen", opened, o),
        join("ClawsClosed", closed, o),
        speck("HookBack", back),
    ]


# --- The wrist launcher ----------------------------------------------------------------------------


def launcher():
    o = LAUNCHER_AT
    muzzle = o + FORWARD * 0.75
    body = [
        rod(o - FORWARD * 0.35, o + FORWARD * 0.6, 0.34, STEEL, vertices=20),
        rod(o - FORWARD * 0.45, o - FORWARD * 0.3, 0.4, DARK, vertices=20),
        rod(o + FORWARD * 0.15, o + FORWARD * 0.35, 0.38, DARK, vertices=20),
    ]
    glow = [ring(o + FORWARD * 0.65, 0.33, 0.07, WHITE, FORWARD, segments=24, sides=6)]
    return [speck("LauncherOrigin", o), join("LauncherBody", body, o), join("LauncherGlow", glow, o), speck("Muzzle", muzzle)]


# --- The bomb ------------------------------------------------------------------------------------


def bomb():
    o = BOMB_AT
    r = BOMB_RADIUS
    body = [
        ball(o, r, NAVY, segs=24, rings=12),
        ball(o + UP * r * 0.92, r * 0.42, STEEL, segs=16, rings=6, scale=(1, 1, 0.35)),
        ball(o - UP * r * 0.92, r * 0.42, STEEL, segs=16, rings=6, scale=(1, 1, 0.35)),
    ]
    glow = [ring(o, r * 1.0, r * 0.07, WHITE, UP, segments=32, sides=6)]
    light = [ball(o + (FORWARD * 0.8 + UP * 0.5).normalized() * r * 0.93, r * 0.2, WHITE, segs=12, rings=6)]
    return [speck("BombOrigin", o), join("BombBody", body, o), join("BombGlow", glow, o), join("BombLight", light, o)]


def wave_ring():
    o = RING_AT
    return [speck("RingOrigin", o), join("Ring", [ring(o, 1.0, 0.045, WHITE, UP, segments=64, sides=6)], o)]


def build():
    return hook() + launcher() + bomb() + wave_ring()


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
    counts = {piece.name: triangles(piece) for piece in pieces}
    print("Wrote", path, len(pieces), "pieces", sum(counts.values()), "triangles", os.path.getsize(path), "bytes")
    print("Triangles:", ", ".join(f"{name} {count}" for name, count in counts.items()))


# --- The check sheet: the pieces as the game dresses them --------------------------------------------

# PvpLooks colours of the Neon pieces.
CYAN = (63, 217, 255)
VIOLET = (140, 100, 255)


def srgb_to_linear(rgb):
    return tuple((c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4 for c in rgb)


def baked():
    m = bpy.data.materials.new("Baked")
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "Col"
    # The game reads the numbers as sRGB: turn them back to linear to match it.
    gamma = nodes.new("ShaderNodeGamma")
    gamma.inputs["Gamma"].default_value = 2.2
    links.new(attribute.outputs["Color"], gamma.inputs["Color"])
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.3
    links.new(gamma.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def neon(rgb, strength=5.0):
    m = bpy.data.materials.new("Neon")
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    color = (*srgb_to_linear(rgb), 1)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Emission Color"].default_value = color
    bsdf.inputs["Emission Strength"].default_value = strength
    return m


def sheet(pieces, path):
    by_name = {piece.name: piece for piece in pieces}
    body, cyan, violet = baked(), neon(CYAN), neon(VIOLET)
    for name, material in (("HookBody", body), ("HookGlow", cyan), ("ClawsOpen", body), ("LauncherBody", body),
                           ("LauncherGlow", cyan), ("BombBody", body), ("BombGlow", violet), ("BombLight", violet),
                           ("Ring", violet)):
        by_name[name].data.materials.append(material)
    # The closed claws beside the open ones; the bomb in its two orbits.
    closed = by_name["ClawsClosed"]
    closed.data.materials.append(body)
    closed.location = HOOK_AT + Vector((0, 0, -2.5))
    for name in ("HookBody", "HookGlow"):
        copy = by_name[name].copy()
        copy.location = closed.location
        bpy.context.scene.collection.objects.link(copy)
    for tilt in ((math.radians(70), 0, math.radians(20)), (math.radians(-60), math.radians(30), 0)):
        orbit = by_name["Ring"].copy()
        orbit.location = BOMB_AT
        orbit.rotation_euler = tilt
        orbit.scale = (1.9, 1.9, 1.9)
        bpy.context.scene.collection.objects.link(orbit)
    for name in ("HookOrigin", "HookBack", "LauncherOrigin", "Muzzle", "BombOrigin", "RingOrigin"):
        by_name[name].hide_render = True

    scene = bpy.context.scene
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.01, 0.012, 0.03, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(-20), math.radians(-30))
    scene.collection.objects.link(sun)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1400, 600
    scene.view_settings.view_transform = "AgX"
    camera = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    camera.data.lens = 40
    camera.location = (8, 22, 6)
    camera.rotation_euler = (Vector((8, 0, -0.8)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Wrote", path)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    pieces = build()
    export(pieces, os.path.join(OUT_DIR, "pvp-kit.glb"))
    if SHEET:
        sheet(pieces, os.path.join(OUT_DIR, "pvp-kit.png"))


if __name__ == "__main__":
    main()
