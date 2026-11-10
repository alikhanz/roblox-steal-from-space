# Concept sheet: an adult guardian next to its baby (the post's main kind), three-quarter front
# and side. One sheet per base family; a draft for review (POLISH queue, item 2).
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/guardians/concept_adults.py -- <out.png> <family> [baby tier] [big]
# `big` puts a legendary baby grown to the adult's size beside it instead (the rejected direction).

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))
sys.path.insert(0, HERE)

import adults  # noqa: E402
import bpy  # noqa: E402
import real  # noqa: E402
import robo  # noqa: E402
import robo_kinds  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "concept_adults.png"
FAMILY = ARGS[1] if len(ARGS) > 1 else "slime"
TIER = int(ARGS[2]) if len(ARGS) > 2 else 1
BIG = len(ARGS) > 3 and ARGS[3] == "big"
GAP = 1.2
FAMILY_TITLES = {"slime": "Слизень", "crab": "Краб", "worm": "Червь", "swarm": "Рой", "ray": "Скат", "whale": "Кит"}
TIER_TITLES = ["обычный", "необычный", "редкий", "эпический", "легендарный"]


def made(make):
    """Runs `make` and returns the top-level objects it added."""
    before = set(bpy.data.objects)
    make()
    bpy.context.view_layer.update()
    return [o for o in set(bpy.data.objects) - before if o.parent is None]


def turn(objects, x, yaw):
    pivot = Matrix.Translation(Vector((x, 0, 0)))
    rotation = pivot @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ pivot.inverted()
    for obj in objects:
        obj.matrix_world = rotation @ obj.matrix_world
    bpy.context.view_layer.update()


def bounds(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    low, high = Vector((math.inf,) * 3), Vector((-math.inf,) * 3)
    for obj in objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        for v in mesh.vertices:
            p = obj.matrix_world @ v.co
            low = Vector(map(min, low, p))
            high = Vector(map(max, high, p))
        evaluated.to_mesh_clear()
    return low, high


def shift(objects, dx, dz=0.0):
    for obj in objects:
        obj.location.x += dx
        obj.location.z += dz
    bpy.context.view_layer.update()


def label(text, location, size):
    bpy.ops.object.text_add(location=location, rotation=(math.radians(90), 0, 0))
    obj = bpy.context.active_object
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = size
    try:
        obj.data.font = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf", check_existing=True)
    except RuntimeError:
        pass
    real.assign(obj, real.glow("Label", (0.75, 0.8, 0.95), 1.2))
    # Not mirrored in the glossy hulls.
    obj.visible_glossy = False
    obj.visible_diffuse = False


def build():
    """Two rows, three-quarter front over side, each the adult with its baby to the right."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kind = next(k for k in robo_kinds.KINDS if k[0] == adults.FAMILIES[FAMILY][1])
    rows = []
    for yaw, view in ((-28, "три четверти"), (90, "сбоку")):
        adult = made(lambda: adults.build(FAMILY, 0, 0))
        turn(adult, 0, yaw)
        low, high = bounds(adult)
        if BIG:
            baby = made(lambda: robo_kinds.build(kind, 4, 0, 0))
            turn(baby, 0, yaw)
            blow, bhigh = bounds(baby)
            robo._grow(baby, 0, 0, (high.z - low.z) / (bhigh.z - blow.z))
            baby_title = "легендарный детёныш, увеличен"
        else:
            baby = made(lambda: robo_kinds.build(kind, TIER, 0, 0))
            turn(baby, 0, yaw)
            baby_title = f"детёныш · {TIER_TITLES[TIER]}"
        blow, bhigh = bounds(baby)
        rows.append((adult, low, high, baby, blow, bhigh, view, baby_title))
    width = max((r[2].x - r[1].x) + GAP + (r[5].x - r[4].x) for r in rows)
    tallest = max(r[2].z for r in rows)
    size = max(0.3, width / 40)
    row_height = tallest + size * 6.5
    for index, (adult, low, high, baby, blow, bhigh, view, baby_title) in enumerate(rows):
        dz = -index * row_height
        row_width = (high.x - low.x) + GAP + (bhigh.x - blow.x)
        left = (width - row_width) / 2
        shift(adult, left - low.x, dz)
        shift(baby, left + (high.x - low.x) + GAP - blow.x, dz)
        label(f"взрослый страж · {view}", (left + (high.x - low.x) / 2, 0, dz - size * 3.2), size)
        label(baby_title, (left + (high.x - low.x) + GAP + (bhigh.x - blow.x) / 2, 0, dz - size * 3.2), size * 0.8)
    label(f"{FAMILY_TITLES[FAMILY]}: {kind[1]}", (width / 2, 0, tallest + size * 1.5), size * 1.5)
    return width, tallest


def corners():
    """Every object's bounding box corners in the world: what the camera must take in."""
    bpy.context.view_layer.update()
    points = []
    for obj in bpy.context.scene.objects:
        if obj.type in ("MESH", "FONT"):
            points += [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return points


def fit(scene, camera, target, direction, points, fill=0.9):
    """Moves the camera along `direction` from `target` until `points` fill the frame, centred."""
    from bpy_extras.object_utils import world_to_camera_view

    distance = 20.0
    for _ in range(6):
        camera.location = target + direction * distance
        camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        bpy.context.view_layer.update()
        seen = [world_to_camera_view(scene, camera, p) for p in points]
        xs, ys = [s.x for s in seen], [s.y for s in seen]
        span = max(max(xs) - min(xs), max(ys) - min(ys))
        frame_w = distance * camera.data.sensor_width / camera.data.lens
        frame_h = frame_w * scene.render.resolution_y / scene.render.resolution_x
        turn = camera.matrix_world.to_3x3()
        target = target + turn @ Vector(((max(xs) + min(xs) - 1) / 2 * frame_w, (max(ys) + min(ys) - 1) / 2 * frame_h, 0))
        distance *= span / fill
    return target


def render(width, tallest):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    points = corners()
    tall = (max(p.z for p in points) - min(p.z for p in points)) / (max(p.x for p in points) - min(p.x for p in points))
    scene.render.resolution_x, scene.render.resolution_y = 2000, max(900, min(2600, round(2000 * tall * 1.12)))
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.6
    world = bpy.data.worlds.new("Space")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    dark = nodes.get("Background")
    dark.inputs["Color"].default_value = (0.006, 0.008, 0.025, 1.0)
    sky = nodes.new("ShaderNodeBackground")
    sky.inputs["Strength"].default_value = 0.35
    texture = nodes.new("ShaderNodeTexSky")
    links.new(texture.outputs["Color"], sky.inputs["Color"])
    path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(sky.outputs["Background"], mix.inputs[1])
    links.new(dark.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], nodes.get("World Output").inputs["Surface"])

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 50
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    rise = math.radians(20)
    target = fit(scene, camera, Vector((width / 2, 0, tallest / 2)), Vector((0, -math.cos(rise), math.sin(rise))), points)

    reach = max(width, tallest * 2.0) * 0.55

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy * (reach / 8) ** 2, size * reach / 8, color
        if name != "Key":
            data.specular_factor = 0.0
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        obj.rotation_euler = (target - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    area("Key", (target.x - reach * 0.8, -reach * 1.6, target.z + reach * 1.1), 9000, 14, (1.0, 0.97, 0.92))
    area("Fill", (target.x + reach * 1.4, -reach * 1.3, target.z + 1), 2400, 16, (0.75, 0.85, 1.0))
    area("Rim", (target.x, reach * 1.4, target.z + reach * 0.8), 10000, 28, (0.55, 0.65, 1.0))
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)


render(*build())
print("Wrote", OUT)
