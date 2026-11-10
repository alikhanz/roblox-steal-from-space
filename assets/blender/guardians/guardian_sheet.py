# Shared pieces of the guardian concept sheets: placing models, labels, a camera that takes in
# everything, and the space look of the pets' sheets.

import math

import bpy
import real
from mathutils import Matrix, Vector


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


def render(out, width, tallest):
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
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


