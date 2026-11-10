# Pieces of the game page's pictures (docs/plans/STAGE_9.md, "Страница игры"): the icon, the
# thumbnails and the community emblem are Blender renders of the game's own models, put together
# here: the standard Roblox character (roblox_avatar.py) on a real jetpack (jetpacks.py), a space egg from
# the egg kit (egg_kit.py), an adult guardian (adults.py), soft glows and flames that a render can
# have (the game draws them with particles), a painted space backdrop and a camera.
#
# Blender units are studs; Z is up; a model faces -Y (docs/design/BLENDER_ROBLOX.md, section 1).
# The shots themselves are in store_shots.py.

import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for folder in ("lib", "aliens", "guardians", "jetpacks", "eggs"):
    path = os.path.join(HERE, "..", folder)
    if path not in sys.path:
        sys.path.insert(0, path)

import adults  # noqa: E402
import bpy  # noqa: E402
import egg_kit  # noqa: E402
import jetpacks  # noqa: E402
import real  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

# --- Placing groups of objects ---------------------------------------------------------------------


def made(make):
    """Runs `make` and returns every object it added."""
    before = set(bpy.data.objects)
    make()
    bpy.context.view_layer.update()
    return [o for o in bpy.data.objects if o not in before]


def place(objects, matrix):
    """Moves a group built about the origin: `matrix` is applied on top of where each top-level
    object is (children follow their parents)."""
    for obj in objects:
        if obj.parent is None:
            obj.matrix_world = matrix @ obj.matrix_world
    bpy.context.view_layer.update()


def pose(location=(0, 0, 0), rotation=(0, 0, 0), scale=1.0):
    """A placement: degrees about X, Y, Z (applied X first), then scale and move."""
    turn = Euler(tuple(math.radians(a) for a in rotation), "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(Vector(location)) @ turn @ Matrix.Scale(scale, 4)


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


def fit(objects, size, location=(0, 0, 0), rotation=(0, 0, 0)):
    """Scales a group so its largest side is `size`, centres it on `location`, then turns it."""
    low, high = bounds(objects)
    centre = (low + high) / 2
    scale = size / max(high - low)
    place(objects, Matrix.Translation(-centre))
    place(objects, pose(location, rotation, scale))
    return objects


# --- Materials -----------------------------------------------------------------------------------


def soft_glow(name, color, strength=6.0, falloff=2.2, alpha=1.0):
    """A glow that fades towards its silhouette: a halo round a ball, a flame along a cone.
    Light without a hard edge, which Roblox Neon can't do but a picture can."""
    # Pure emission over transparency: no lit surface, so no white highlights wash the colour out.
    mat, nodes, links, bsdf = real._principled(name)
    nodes.remove(bsdf)
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (*color, 1.0)
    emission.inputs["Strength"].default_value = strength
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], nodes.get("Material Output").inputs["Surface"])
    weight = nodes.new("ShaderNodeLayerWeight")
    weight.inputs["Blend"].default_value = 0.5
    invert = nodes.new("ShaderNodeMath")
    invert.operation = "SUBTRACT"
    invert.inputs[0].default_value = 1.0
    links.new(weight.outputs["Facing"], invert.inputs[1])
    power = nodes.new("ShaderNodeMath")
    power.operation = "POWER"
    power.inputs[1].default_value = falloff
    links.new(invert.outputs[0], power.inputs[0])
    scaled = nodes.new("ShaderNodeMath")
    scaled.operation = "MULTIPLY"
    scaled.inputs[1].default_value = alpha
    links.new(power.outputs[0], scaled.inputs[0])
    links.new(scaled.outputs[0], mix.inputs["Fac"])
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    if hasattr(mat, "use_transparency_overlap"):
        mat.use_transparency_overlap = False
    return mat


def rim_glass(name, color, edge=0.7):
    """Clear glass that shows only towards its silhouette (a bubble helmet): the face inside
    stays clear, the rim catches the light."""
    mat, nodes, links, bsdf = real._principled(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.03
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 0.08
    weight = nodes.new("ShaderNodeLayerWeight")
    weight.inputs["Blend"].default_value = 0.5
    power = nodes.new("ShaderNodeMath")
    power.operation = "POWER"
    power.inputs[1].default_value = 3.0
    links.new(weight.outputs["Facing"], power.inputs[0])
    scaled = nodes.new("ShaderNodeMath")
    scaled.operation = "MULTIPLY"
    scaled.inputs[1].default_value = edge
    links.new(power.outputs[0], scaled.inputs[0])
    links.new(scaled.outputs[0], bsdf.inputs["Alpha"])
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    if hasattr(mat, "use_backface_culling"):
        mat.use_backface_culling = True
    return mat


def no_shadow(obj):
    obj.visible_shadow = False
    return obj


def glow_ball(location, radius, color, strength=5.0, falloff=2.2, alpha=1.0, squash=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = "Glow"
    obj.scale = squash
    real.assign(obj, soft_glow("GlowBall", color, strength, falloff, alpha))
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return no_shadow(obj)


def point_light(location, color, energy, radius=0.5):
    data = bpy.data.lights.new("Point", "POINT")
    data.color, data.energy, data.shadow_soft_size = color, energy, radius
    obj = bpy.data.objects.new("Point", data)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    return obj


def area_light(location, target, color, energy, size):
    data = bpy.data.lights.new("Area", "AREA")
    data.color, data.energy, data.size = color, energy, size
    obj = bpy.data.objects.new("Area", data)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- Jets ---------------------------------------------------------------------------------------------------


def flame(location, direction, length=3.0, radius=0.32, color=(1.0, 0.28, 0.02), core=(1.0, 0.72, 0.22)):
    """A jet from a nozzle: a soft outer cone, a hot core and a light. Returns its objects."""
    before = set(bpy.data.objects)
    direction = Vector(direction).normalized()
    turn = direction.to_track_quat("-Z", "Y").to_matrix().to_4x4()
    for r, length_k, col, strength, falloff in ((radius, 1.0, color, 3.0, 1.1), (radius * 0.5, 0.55, core, 6.0, 1.0)):
        bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=r, radius2=0.0, depth=length * length_k)
        cone = bpy.context.active_object
        # The cone's base at the nozzle, its tip down the jet (its local −Z).
        cone.matrix_world = Matrix.Translation(Vector(location)) @ turn @ Matrix.Translation((0, 0, -length * length_k / 2)) @ Matrix.Rotation(math.pi, 4, "X")
        real.assign(cone, soft_glow("Flame", col, strength, falloff))
        for poly in cone.data.polygons:
            poly.use_smooth = True
        no_shadow(cone)
    glow_ball(Vector(location) + direction * 0.25, radius * 0.9, color, 6.0, 2.0, 0.7)
    point_light(Vector(location) + direction * 0.8, color, 120 * radius / 0.32, 0.3)
    return [o for o in bpy.data.objects if o not in before]


# --- The egg -----------------------------------------------------------------------------------------

# EggLooks: the glow colours of the rarities, the gold cap (egg_kit.GLOW_COLORS, GOLD).
EGG_LIGHT = {"Rare": (0.35, 0.67, 1.0), "Epic": (0.78, 0.35, 1.0), "Legendary": (1.0, 0.78, 0.24), "Uncommon": (0.47, 0.92, 0.51)}


def egg(rarity="Legendary", halo=1.0, light=1.0):
    """The game's egg (egg kit pieces dressed as World/EggModel does) about the origin, a medium
    egg (1.6 × 2.1 studs), its window facing −Y, with a soft halo and a light of its rarity."""
    before = set(bpy.data.objects)
    body = egg_kit.body(rarity)
    real.assign(body, egg_kit.baked())
    glow = egg_kit.glow(rarity)
    real.assign(glow, egg_kit.neon(egg_kit.GLOW_COLORS[rarity], 4.0))
    if rarity == "Legendary":
        cap = egg_kit.gold_cap()
        real.assign(cap, egg_kit.metal(egg_kit.GOLD))
    color = EGG_LIGHT[rarity]
    if halo > 0:
        glow_ball((0, 0, 0), 1.45 * halo, color, 2.5, 3.0, 0.55)
    if light > 0:
        point_light((0, -1.6, 0.4), color, 260 * light, 0.6)
    return [o for o in bpy.data.objects if o not in before]


# --- A guardian --------------------------------------------------------------------------------------


def guardian(kind_id):
    """An adult guardian (adults.py) about the origin, facing −Y."""
    kind = adults.kind_of(kind_id)
    return made(lambda: adults.build(kind, 0, 0))


# --- The station ----------------------------------------------------------------------------------------

# StationSize: the platform's radius and the dome over it (studs).
PLATFORM_RADIUS = 60
DOME_RADIUS = 90


def station(location=(0, 0, 0), scale=1.0):
    """The central station as a silhouette: the platform with its lit rim, the hull under it, the
    glass dome and the coin crown in the middle (decision 087). Not the game's kit, a stand-in
    for a far view."""
    before = set(bpy.data.objects)
    hull = real.gloss("Hull", (0.55, 0.6, 0.72), 0.35, 0.4)
    deck = real.gloss("Deck", (0.78, 0.8, 0.86), 0.4)
    neon = real.glow("Rim", (0.3, 0.85, 1.0), 6.0)
    gold = real.glow("Crown", (1.0, 0.75, 0.2), 5.0)
    r = PLATFORM_RADIUS
    jetpacks.cylinder((0, 0, -2), r, 4, "station", deck, vertices=96, bevel=0.6)
    jetpacks.cylinder((0, 0, -16), r * 0.98, 24, "station", hull, radius2=r * 0.35, vertices=96, bevel=0)
    jetpacks.cylinder((0, 0, -34), r * 0.35, 12, "station", hull, radius2=r * 0.12, vertices=64, bevel=0)
    jetpacks.torus((0, 0, -2), r + 0.4, 1.0, "station", neon)
    jetpacks.torus((0, 0, -14), r * 0.82, 0.8, "station", neon)
    for index in range(16):
        angle = index / 16 * math.tau
        jetpacks.sphere((math.cos(angle) * r * 0.62, math.sin(angle) * r * 0.62, -24), 1.6, "station", neon)
    # The dome: a cap of a sphere meeting the platform's rim.
    rise = 34.0
    radius = (r * r + rise * rise) / (2 * rise)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=radius, location=(0, 0, rise - radius))
    dome = bpy.context.active_object
    for poly in dome.data.polygons:
        poly.use_smooth = True
    import bmesh
    mesh = bmesh.new()
    mesh.from_mesh(dome.data)
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if v.co.z + (rise - radius) < 0.0], context="VERTS")
    mesh.to_mesh(dome.data)
    mesh.free()
    real.assign(dome, rim_glass("Dome", (0.55, 0.85, 1.0), 0.55))
    no_shadow(dome)
    # The crown: a ring of screens over the middle, gold light.
    jetpacks.torus((0, 0, 20), 9, 0.9, "station", gold)
    jetpacks.cylinder((0, 0, 10), 2.5, 20, "station", hull, vertices=32, bevel=0)
    for index in range(4):
        angle = index / 4 * math.tau + math.pi / 4
        jetpacks.pill((math.cos(angle) * 9, math.sin(angle) * 9, 15), (4.5, 0.4, 3.0), "station",
                      real.glow("Screen", (0.3, 0.6, 1.0), 2.0), rotation=(0, 0, angle + math.pi / 2))
    # Kiosks round the plaza.
    for index in range(6):
        angle = index / 6 * math.tau
        jetpacks.capsule((math.cos(angle) * 38, math.sin(angle) * 38, 4), 3.0, 8, "station", deck)
        jetpacks.torus((math.cos(angle) * 38, math.sin(angle) * 38, 6), 3.1, 0.35, "station",
                       real.glow("Kiosk", [(0.3, 1.0, 0.5), (1.0, 0.6, 0.2), (1.0, 0.35, 0.65)][index % 3], 5.0))
    objects = [o for o in bpy.data.objects if o not in before]
    place(objects, pose(location, (0, 0, 0), scale))
    return objects


# --- Space ----------------------------------------------------------------------------------------------


def world(reflect=(0.32, 0.36, 0.6)):
    """What metal and glass reflect: a soft blue-violet sky (the camera sees the backdrop)."""
    scene = bpy.context.scene
    w = bpy.data.worlds.new("Space")
    scene.world = w
    w.use_nodes = True
    w.node_tree.nodes.get("Background").inputs["Color"].default_value = (*reflect, 1.0)
    w.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.5


def backdrop(camera, distance, inner=(0.18, 0.12, 0.55), outer=(0.01, 0.01, 0.05), centre=(0.0, 0.0),
             nebula=((0.55, 0.15, 0.6), (0.05, 0.45, 0.65)), stars=1.0, seed=3):
    """A painted sky facing the camera `distance` away: a radial glow from `centre` (in frame
    units, 0 is the middle), two nebula colours in clouds, and stars."""
    scene = bpy.context.scene
    cam = camera.data
    aspect = scene.render.resolution_x / scene.render.resolution_y
    width = 2 * distance * math.tan(cam.angle / 2) * (1 if aspect >= 1 else aspect) * 1.08
    height = width / aspect
    bpy.ops.mesh.primitive_plane_add(size=1)
    plane = bpy.context.active_object
    plane.name = "Backdrop"
    plane.scale = (width, height, 1)
    plane.matrix_world = camera.matrix_world @ Matrix.Translation((0, 0, -distance)) @ Matrix.Diagonal((width, height, 1, 1))
    mat = bpy.data.materials.new("Backdrop")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = 1.0
    links.new(emit.outputs[0], out.inputs[0])
    coord = nodes.new("ShaderNodeTexCoord")
    # Frame units: the plane's UV 0..1 → (−aspect..aspect, −1..1) about `centre`.
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["UV"], sep.inputs[0])

    def math_node(op, a, b):
        node = nodes.new("ShaderNodeMath")
        node.operation = op
        for index, value in enumerate((a, b)):
            if isinstance(value, (int, float)):
                node.inputs[index].default_value = value
            else:
                links.new(value, node.inputs[index])
        return node.outputs[0]

    x = math_node("MULTIPLY", math_node("SUBTRACT", sep.outputs["X"], 0.5 + centre[0] / 2), 2 * aspect)
    y = math_node("MULTIPLY", math_node("SUBTRACT", sep.outputs["Y"], 0.5 + centre[1] / 2), 2.0)
    r = math_node("SQRT", math_node("ADD", math_node("MULTIPLY", x, x), math_node("MULTIPLY", y, y)), 0.0)
    radial = nodes.new("ShaderNodeValToRGB")
    els = radial.color_ramp.elements
    els[0].position, els[0].color = 0.0, (*inner, 1)
    els[1].position, els[1].color = 1.25, (*outer, 1)
    links.new(math_node("MULTIPLY", r, 0.8), radial.inputs[0])
    # Nebula clouds.
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.2
    noise.inputs["Detail"].default_value = 8.0
    noise.inputs["Roughness"].default_value = 0.6
    if "W" in noise.inputs:
        noise.noise_dimensions = "4D"
        noise.inputs["W"].default_value = seed
    links.new(coord.outputs["UV"], noise.inputs["Vector"])
    clouds = nodes.new("ShaderNodeValToRGB")
    ce = clouds.color_ramp.elements
    ce[0].position, ce[0].color = 0.42, (0, 0, 0, 1)
    ce.new(0.55).color = (*nebula[0], 1)
    ce[-1].position, ce[-1].color = 0.75, (*nebula[1], 1)
    links.new(noise.outputs["Fac"], clouds.inputs[0])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "ADD"
    mix.inputs["Factor"].default_value = 0.32
    links.new(radial.outputs[0], mix.inputs[6])
    links.new(clouds.outputs[0], mix.inputs[7])
    # Stars: small bright dots of two sizes.
    last = mix.outputs[2]
    for scale, size, strength in ((90.0, 0.06, 1.6 * stars), (28.0, 0.035, 3.0 * stars)):
        vor = nodes.new("ShaderNodeTexVoronoi")
        vor.inputs["Scale"].default_value = scale
        stretched = nodes.new("ShaderNodeVectorMath")
        stretched.operation = "MULTIPLY"
        stretched.inputs[1].default_value = (aspect, 1.0, 1.0)
        links.new(coord.outputs["UV"], stretched.inputs[0])
        links.new(stretched.outputs[0], vor.inputs["Vector"])
        dot = math_node("LESS_THAN", vor.outputs["Distance"], size)
        add = nodes.new("ShaderNodeMix")
        add.data_type = "RGBA"
        add.blend_type = "ADD"
        add.inputs["Factor"].default_value = strength
        links.new(last, add.inputs[6])
        links.new(dot, add.inputs[7])
        last = add.outputs[2]
    links.new(last, emit.inputs["Color"])
    plane.data.materials.append(mat)
    plane.visible_shadow = False
    plane.visible_diffuse = False
    plane.visible_glossy = False
    return plane


# --- Camera and render --------------------------------------------------------------------------------


def camera(location, target, lens=50.0, roll=0.0):
    data = bpy.data.cameras.new("Camera")
    data.lens = lens
    data.clip_end = 20000
    obj = bpy.data.objects.new("Camera", data)
    obj.location = location
    direction = Vector(target) - Vector(location)
    turn = direction.to_track_quat("-Z", "Y").to_matrix() @ Matrix.Rotation(math.radians(roll), 3, "Z")
    obj.rotation_euler = turn.to_euler()
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.scene.camera = obj
    bpy.context.view_layer.update()
    return obj


def setup(resolution, fast=False):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", not fast), ("taa_render_samples", 16 if fast else 96)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 50 if fast else 100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.2
    scene.render.film_transparent = False


def outline(thickness=3.0, exclude=()):
    """A dark cartoon line round silhouettes (Freestyle), not round glows and the backdrop."""
    scene = bpy.context.scene
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = thickness
    settings = scene.view_layers[0].freestyle_settings
    lineset = settings.linesets[0] if len(settings.linesets) > 0 else settings.linesets.new("Outline")
    lineset.linestyle = lineset.linestyle or bpy.data.linestyles.new("Outline")
    lineset.linestyle.color = (0.02, 0.02, 0.06)
    lineset.select_by_edge_types = True
    lineset.select_silhouette = True
    lineset.select_border = True
    lineset.select_crease = False
    plain = bpy.data.collections.new("NoOutline")
    scene.collection.children.link(plain)
    for obj in exclude:
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        plain.objects.link(obj)
    lineset.select_by_collection = True
    lineset.collection = plain
    lineset.collection_negation = "EXCLUSIVE"


def glowing(objects):
    """Objects that are light, not surfaces (no outline round them)."""
    out = []
    for obj in objects:
        for slot in getattr(obj, "material_slots", []):
            if slot.material and slot.material.name.startswith(("GlowBall", "Flame", "Helmet", "Backdrop", "Streak", "Dome", "Sparkle")):
                out.append(obj)
                break
    return out


def render(path):
    scene = bpy.context.scene
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print("Wrote", path)


def rng(seed):
    return random.Random(seed)


# --- Genre look: bright space, a planet, speed lines -------------------------------------------------


def planet(location, radius, colors=((0.35, 0.2, 0.75), (0.95, 0.45, 0.8), (0.3, 0.8, 1.0)), atmosphere=(0.5, 0.8, 1.0), seed=4):
    """A big banded planet with a glowing rim of air: the ground of a space picture."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = "Planet"
    for poly in obj.data.polygons:
        poly.use_smooth = True
    mat, nodes, links, bsdf = real._principled("Planet")
    bsdf.inputs["Roughness"].default_value = 0.6
    coord = nodes.new("ShaderNodeTexCoord")
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 1.6
    wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 4.0
    links.new(coord.outputs["Generated"], wave.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (*colors[0], 1)
    els.new(0.55).color = (*colors[1], 1)
    els[-1].position, els[-1].color = 1.0, (*colors[2], 1)
    links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    real.assign(obj, mat)
    glow_ball(location, radius * 1.04, atmosphere, 4.0, 5.0, 0.9)
    return obj


def speed_lines(camera, distance, count, area, direction=(-1.0, -0.12), color=(0.85, 0.95, 1.0), seed=7, alpha=0.8):
    """Streaks across part of the frame (`area`: x0, y0, x1, y1 in frame units, −1..1), as in
    the genre's chase pictures: thin glowing strokes along `direction` (frame units)."""
    random_ = random.Random(seed)
    scene = bpy.context.scene
    aspect = scene.render.resolution_x / scene.render.resolution_y
    half_w = distance * math.tan(camera.data.angle / 2) * (1 if aspect >= 1 else aspect)
    half_h = half_w / aspect
    angle = math.atan2(direction[1], direction[0])
    mat = soft_glow("Streak", color, 4.0, 0.8, alpha)
    out = []
    for _ in range(count):
        fx = random_.uniform(area[0], area[2])
        fy = random_.uniform(area[1], area[3])
        length = random_.uniform(0.3, 1.0) * half_w
        thickness = random_.uniform(0.003, 0.016) * half_w
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.0, depth=1.0)
        streak = bpy.context.active_object
        streak.name = "Streak"
        real.assign(streak, mat)
        local = Matrix.Translation((fx * half_w, fy * half_h, -distance)) @ Matrix.Rotation(angle, 4, "Z") \
            @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Diagonal((thickness, thickness, length, 1))
        streak.matrix_world = camera.matrix_world @ local
        no_shadow(streak)
        out.append(streak)
    return out


def sun(direction, color, energy):
    """Sunlight along `direction`: lights big far things (a planet) the area lights don't reach."""
    data = bpy.data.lights.new("Sun", "SUN")
    data.color, data.energy, data.angle = color, energy, math.radians(2)
    obj = bpy.data.objects.new("Sun", data)
    obj.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(obj)
    return obj


def sparkle(location, size, color=(1.0, 0.95, 0.8), strength=8.0, turn=0.0):
    """A four-point twinkle: two thin glowing spindles crossed, facing −Y."""
    mat = soft_glow("Sparkle", color, strength, 0.6)
    out = []
    for angle in (0.0, math.pi / 2):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1.0)
        spindle = bpy.context.active_object
        spindle.scale = (size * 0.09, size * 0.02, size)
        spindle.rotation_euler = (0, angle + turn, 0)
        spindle.location = location
        real.assign(spindle, mat)
        out.append(no_shadow(spindle))
    return out


# --- The pilot as the standard Roblox character ----------------------------------------------------------


def avatar_pilot(grade=6, arms="overhead", legs="run", head_turn=0.0, pack_scale=1.4, colors=None, arm_back=178):
    """The standard R6 Roblox character (roblox_avatar.py, from the Studio install) wearing jetpack
    `grade`, about its torso centre, facing −Y. Returns its objects and its flame points."""
    import roblox_avatar

    pose = {"Head": (0, 0, head_turn)}
    if arms == "overhead":
        # Straight up and a little out (Blender: the left arm is at +X).
        pose["Left Arm"] = (arm_back, 14, 0)
        pose["Right Arm"] = (arm_back, -14, 0)
    elif arms == "trophy":
        # One arm (the right, at −X) holds the egg up. The other swings back level (positive X is
        # back): hanging, it covered the body and lined up with the leg below (user, 2026-11-11).
        pose["Right Arm"] = (arm_back, -6, 0)
        pose["Left Arm"] = (80, -12, 0)
    if legs == "run":
        pose["Left Leg"] = (-34, 0, 0)
        pose["Right Leg"] = (38, 0, 0)
    before = set(bpy.data.objects)
    parts = roblox_avatar.build(colors or roblox_avatar.CLASSIC, pose)
    if arms in ("overhead", "trophy"):
        # Picture licence: arms raised from the shoulder's top so the hands reach over the head.
        for name in ("Left Arm", "Right Arm") if arms == "overhead" else ("Right Arm",):
            for obj in parts[name]:
                obj.matrix_world = Matrix.Translation((0, 0, 0.55)) @ obj.matrix_world
    pack = jetpacks.build(grade)
    grow = Matrix.Translation((0, 0.5, 0.1)) @ Matrix.Scale(pack_scale, 4) @ Matrix.Translation((0, -0.5, 0))
    for obj in pack:
        if obj.parent is None:
            obj.matrix_world = grow @ obj.matrix_world
    bpy.context.view_layer.update()
    flames = [(o.matrix_world.translation.copy(), Vector((0, 0, -1))) for o in pack if o.get("role") == "nozzle"]
    return [o for o in bpy.data.objects if o not in before], flames
