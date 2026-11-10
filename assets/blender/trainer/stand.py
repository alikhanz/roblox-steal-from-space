# The jetpack stand's six tiers (decision 091; docs/design/screens/jetpack-stand.md): a new model
# every three trainer levels, the last the top. Shared by the concept renders (concept_stand.py)
# and the game's kit (stand_kit.py).
#
# Studs = Blender units. The stand's frame: the platform's centre on the floor is the origin, its
# top P (StandConfig.PLATFORM_HEIGHT) high; the rider stands on the origin facing -Y (the island's
# centre; -Z, the look vector, in Roblox), the frame stands behind, +Y. The game's camera sits
# behind and above the rider, so nothing behind the platform rises higher than a duct.
#
# Every part carries a role (`obj["role"]`), the contract with the game (BLENDER_ROBLOX.md,
# section 3: anything the game recolours, hides or lights gets its own role):
#   steel, light, dark, pearl, navy, top - the plastic body; colours baked into the vertices (Body)
#   gold   - polished metal, the top tier only (Gold, PetMetal in game)
#   glow   - the trainer's yellow light (Glow, Neon)
#   hot    - where the flame lands: the grate in the platform, the hot rings, the ducts' mouths
#            (Grate: the client heats it while the owner trains)
#   pilot  - the pilot lights, lit while the stand is empty (Pilot: the client hides them)
# The level dial's lamps are not here: the game sets them per level (BayModel).

import math

import bmesh
import bpy

P = 0.6  # the platform's top (StandConfig.PLATFORM_HEIGHT)

# Game detail (stand_kit.py) or render detail (concepts). A stand stands on each of 8 islands.
LOW_POLY = False

# How a role becomes a material: set by the caller (the concept's shaders, the kit's paints).
MATERIALS = {}


def _seg(full, low):
    return low if LOW_POLY else full


def _tag(obj, role):
    obj["role"] = role
    material = MATERIALS.get(role)
    if material is not None:
        obj.data.materials.clear()
        obj.data.materials.append(material)
    return obj


def _smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


# --- Shapes ------------------------------------------------------------------------------------


def rbox(size, location, role, bevel=0.15, rotation=(0, 0, 0)):
    """A box with rounded edges."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = min(bevel, min(size) * 0.49)
        mod.segments = _seg(4, 2)
        mod.limit_method = "NONE"
        _smooth(obj)
        obj.modifiers.new("Normals", "WEIGHTED_NORMAL").keep_sharp = True
    return _tag(obj, role)


def cyl(radius, depth, location, role, rotation=(0, 0, 0), vertices=64, radius2=None, bevel=0.0):
    vertices = _seg(vertices, max(12, vertices // 2 if radius > 1.5 else vertices // 3))
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=radius2, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    _smooth(obj)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = _seg(3, 1)
        mod.limit_method = "ANGLE"
    return _tag(obj, role)


def ball(radius, location, role, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=_seg(32, 12), ring_count=_seg(16, 6))
    obj = bpy.context.active_object
    obj.scale = scale
    _smooth(obj)
    return _tag(obj, role)


def capsule(radius, height, location, role):
    """A tank: a cylinder with round ends, `height` end to end, standing along Z."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=_seg(32, 14), ring_count=_seg(16, 8))
    obj = bpy.context.active_object
    half = max(0.0, height / 2 - radius)
    for v in obj.data.vertices:
        v.co.z += half if v.co.z > 0 else -half if v.co.z < 0 else 0
    _smooth(obj)
    return _tag(obj, role)


def ring(major, minor, location, role, rotation=(0, 0, 0), keep=None):
    """A torus. `keep(x, y, z)` (its own coordinates, before the turn) keeps part of it: an arch."""
    major_segments = _seg(96, max(16, int(major * 12)))
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=location, rotation=rotation, major_segments=major_segments, minor_segments=_seg(16, 6))
    obj = bpy.context.active_object
    if keep:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        gone = [v for v in bm.verts if not keep(*v.co)]
        bmesh.ops.delete(bm, geom=gone, context="VERTS")
        bm.to_mesh(obj.data)
        bm.free()
    _smooth(obj)
    return _tag(obj, role)


def octa(radius, location, role, stretch=1.6):
    """A floating crystal: an octahedron stretched upright."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=4, ring_count=2)
    obj = bpy.context.active_object
    obj.scale = (1, 1, stretch)
    return _tag(obj, role)


def at_angle(radius, degrees, z):
    """A point on a circle round the platform: 0 degrees straight behind (+Y)."""
    a = math.radians(degrees)
    return (radius * math.sin(a), radius * math.cos(a), z)


# --- Common pieces -----------------------------------------------------------------------------


def platform(radius, steps=1):
    """The solid platform: `steps` stacked discs, the lower ones wider, its top P high, a lit rim."""
    h = P / steps
    for s in range(steps):
        cyl(radius + (steps - 1 - s) * 0.35, h, (0, 0, h * (s + 0.5)), "steel", bevel=0.06)
    cyl(radius - 0.45, 0.04, (0, 0, P), "top")
    ring(radius + 0.01, 0.05, (0, 0, P - 0.06), "glow")


def floating_platform(radius, base, rim):
    """The platform of the top tiers: a thin disc over a pedestal, lit from under it."""
    cyl(base, 0.25, (0, 0, 0.125), "dark", bevel=0.05)
    cyl(base * 0.64, 0.2, (0, 0, 0.3), rim)
    cyl(radius, 0.28, (0, 0, P - 0.14), "pearl" if rim == "gold" else "steel", bevel=0.06)
    cyl(radius - 0.45, 0.04, (0, 0, P), "top" if rim != "gold" else "navy")


def rail(width, z=P + 2.6, y=-1.3, grips=False, role="light"):
    """The rail at the rider's hands: two posts and a bar, rounded."""
    for side in (-1, 1):
        rbox((0.24, 0.24, z - P), (side * width / 2, y, (z + P) / 2), role, 0.08)
    rbox((width + 0.24, 0.26, 0.26), (0, y, z), role, 0.12)
    if grips:
        for side in (-1, 1):
            cyl(0.16, 0.5, (side * 0.75, y, z), "glow", rotation=(0, math.radians(90), 0), vertices=24)


def blast(size, rim, rings=0, ducts=0, duct="steel", reach=3.0):
    """Where the flame lands: a hot grate set into the platform behind the rider's heels (the
    jetpack fires straight down), from tier 2 on low exhaust ducts out of the platform's back.
    Everything behind the rider stays low: the camera looks over it."""
    w, d = size
    y = 0.45 + d / 2
    rbox((w + 0.3, d + 0.3, 0.06), (0, y, P + 0.01), rim, 0.1)
    rbox((w, d, 0.07), (0, y, P + 0.02), "hot", 0.08)
    for i in range(5):
        rbox((w - 0.15, 0.07, 0.1), (0, y - d / 2 + 0.15 + i * (d - 0.3) / 4, P + 0.04), "dark", 0.02)
    for i in range(rings):
        ring(0.35 + 0.25 * i, 0.04, (0, y, P + 0.07), "hot")
    for i in range(ducts):
        x = (i - (ducts - 1) / 2) * 1.1
        turn = (math.radians(90), 0, 0)
        cyl(0.32, 1.2, (x, reach + 0.35, 0.42), duct, rotation=turn, vertices=32, bevel=0.04)
        cyl(0.36, 0.12, (x, reach + 0.95, 0.42), "dark", rotation=turn, vertices=32)
        cyl(0.26, 0.05, (x, reach + 1.02, 0.42), "hot", rotation=turn, vertices=32)


def pilots(x, y, z, radius=0.17):
    """The pair of pilot lights, on either side."""
    for side in (-1, 1):
        ball(radius, (side * x, y, z), "pilot")


# --- The tiers ---------------------------------------------------------------------------------


def tier1():
    """The bare test frame (the greybox, rounded): two slim pillars and a bar behind the rider, a
    rail in front, the grate in the platform."""
    platform(3.0)
    for side in (-1, 1):
        rbox((0.38, 0.38, 4.8), (side * 1.4, 1.2, P + 2.4), "steel", 0.12)
        rbox((0.6, 0.6, 0.3), (side * 1.4, 1.2, P + 0.15), "dark", 0.08)
    rbox((3.2, 0.36, 0.36), (0, 1.2, P + 4.3), "steel", 0.14)
    rbox((0.5, 0.6, 0.3), (0, 0.85, P + 4.3), "dark", 0.1)  # the clamp
    rail(2.6)
    blast((1.6, 1.2), "dark")
    pilots(1.4, 0.95, P + 0.9)


def tier2():
    """The stand: thicker pillars with pearl shoulders and lit stripes, a yoke clamping the
    jetpack, a lamp bar over it, grips on the rail, pearl fuel cells at both sides, an exhaust
    duct."""
    platform(3.1, steps=2)
    for side in (-1, 1):
        rbox((0.6, 0.6, 5.0), (side * 1.55, 1.25, P + 2.5), "steel", 0.2)
        rbox((0.9, 0.9, 0.55), (side * 1.55, 1.25, P + 5.05), "pearl", 0.25)
        # Lit stripes on the pillars' backs: the camera sees them.
        rbox((0.14, 0.08, 3.4), (side * 1.55, 1.57, P + 2.6), "glow", 0.03)
        # The yoke's arms reach forward to the jetpack's sides.
        rbox((0.22, 0.9, 0.26), (side * 1.05, 0.95, P + 4.2), "dark", 0.08)
        capsule(0.42, 1.8, (side * 2.45, 0.9, P + 0.95), "pearl")
        ring(0.43, 0.05, (side * 2.45, 0.9, P + 1.2), "glow")
    rbox((3.6, 0.5, 0.5), (0, 1.25, P + 4.5), "steel", 0.2)
    for x in (-0.6, 0, 0.6):
        ball(0.16, (x, 1.25, P + 4.82), "glow")
    rail(2.7, grips=True)
    blast((1.8, 1.3), "dark", ducts=1, reach=3.1)
    pilots(1.55, 0.88, P + 0.9)


def tier3():
    """The test rig: an arch over the rider's back with lamps, pearl coolant tanks behind with
    hoses, gauge consoles at the sides."""
    platform(3.3, steps=2)
    r, cz = 2.1, P + 3.6
    turn = (math.radians(90), 0, 0)
    for side in (-1, 1):
        rbox((0.6, 0.6, cz - P), (side * r, 1.3, (cz + P) / 2), "steel", 0.2)
    ring(r, 0.3, (0, 1.3, cz), "steel", rotation=turn, keep=lambda x, y, z: y >= -0.05)
    ring(r - 0.3, 0.06, (0, 1.0, cz), "glow", rotation=turn, keep=lambda x, y, z: y >= -0.05)
    for deg in (-50, 0, 50):
        a = math.radians(deg)
        ball(0.17, (r * math.sin(a), 0.95, cz + r * math.cos(a)), "glow")
    rbox((0.5, 0.7, 0.35), (0, 0.85, P + 4.35), "dark", 0.12)  # the clamp
    for side in (-1, 1):
        capsule(0.5, 2.6, (side * 2.6, 2.3, P + 1.3), "pearl")
        for z in (0.7, 1.9):
            ring(0.51, 0.05, (side * 2.6, 2.3, P + z), "glow")
        ring(0.55, 0.09, (side * 2.35, 1.75, P + 2.65), "dark", rotation=(math.radians(90), 0, math.radians(90)), keep=lambda x, y, z: z >= 0 or y >= 0)
        # A gauge console at the side: a pedestal with a sloped navy face.
        rbox((0.7, 0.7, 1.4), (side * 2.9, -0.6, P + 0.7), "steel", 0.18)
        rbox((0.8, 0.12, 0.6), (side * 2.9, -0.95, P + 1.55), "navy", 0.05, rotation=(math.radians(35), 0, 0))
        for i in range(3):
            rbox((0.12, 0.03, 0.15 + 0.12 * i), (side * 2.9 - 0.2 + i * 0.2, -1.03, P + 1.45 + 0.06 * i), "glow", 0.01, rotation=(math.radians(35), 0, 0))
    rail(2.7, grips=True)
    blast((2.0, 1.4), "light", rings=1, ducts=2, reach=3.3)
    pilots(r, 0.93, P + 0.9)


def tier4():
    """The accelerator: a big ring standing round the rider with glowing coils, four lamp pylons
    on the rim, side fins, hot exhaust ducts."""
    platform(3.5, steps=2)
    ring(3.48, 0.08, (0, 0, P - 0.02), "pearl")
    cz, big = P + 3.2, 3.05
    # The ring stands across the platform, in the rider's shoulder plane: the camera behind looks
    # through it.
    ring(big, 0.28, (0, 0.25, cz), "light", rotation=(math.radians(90), 0, 0), keep=lambda x, y, z: y > -big * 0.93)
    for deg in (-110, -70, 70, 110, 0):
        a = math.radians(deg)
        ring(0.38, 0.1, (big * math.sin(a), 0.25, cz + big * math.cos(a)), "glow", rotation=(0, math.radians(90), -a))
    for side in (-1, 1):
        rbox((0.8, 0.9, 0.6), (side * 2.9, 0.25, P + 0.3), "dark", 0.15)
        rbox((0.12, 1.4, 1.0), (side * (big + 0.35), 0.6, cz), "steel", 0.05, rotation=(math.radians(20), 0, 0))
    rbox((0.45, 0.9, 0.3), (0, 0.75, P + 4.4), "dark", 0.12)  # the clamp, hanging from the ring
    rbox((0.3, 0.3, cz + big - P - 4.4), (0, 0.6, (P + 4.4 + cz + big) / 2), "steel", 0.1)
    for deg in (135, -135, 45, -45):
        x, y, _ = at_angle(3.2, deg, 0)
        rbox((0.35, 0.35, 1.6), (x, y, P + 0.8), "steel", 0.12)
        ball(0.22, (x, y, P + 1.75), "glow")
    rail(2.7, grips=True)
    blast((2.1, 1.5), "light", rings=2, ducts=2, reach=3.5)
    pilots(2.9, -0.25, P + 0.35, 0.15)


def tier5():
    """The gyroscope: the platform floats on a pedestal with a glow under it; a standing ring and
    a waist ring of pearl ceramic round the rider; crystals hovering over the pylons."""
    floating_platform(3.8, 2.2, "steel")
    ring(3.6, 0.07, (0, 0, P - 0.3), "glow")  # under the platform
    ring(3.81, 0.05, (0, 0, P - 0.05), "glow")
    cz = P + 3.2
    turn = (math.radians(90), 0, 0)
    ring(3.15, 0.26, (0, 0.2, cz), "pearl", rotation=turn, keep=lambda x, y, z: y > -3.0)
    ring(3.15, 0.06, (0, -0.06, cz), "glow", rotation=turn, keep=lambda x, y, z: y > -3.0)
    ring(3.0, 0.2, (0, 0, P + 2.0), "pearl", keep=lambda x, y, z: y > -1.9)  # open in front
    ring(3.0, 0.05, (0, 0, P + 2.21), "glow", keep=lambda x, y, z: y > -1.9)
    for side in (-1, 1):
        rbox((0.9, 0.9, 0.7), (side * 3.0, 0.2, P + 0.35), "dark", 0.2)
        rbox((0.3, 0.3, 1.4), (side * 3.0, 0.2, P + 1.3), "light", 0.1)
    rbox((0.5, 1.0, 0.32), (0, 0.75, P + 4.4), "dark", 0.12)
    rbox((0.3, 0.3, cz + 3.15 - P - 4.4), (0, 0.55, (P + 4.4 + cz + 3.15) / 2), "steel", 0.1)
    for deg in (140, -140, 40, -40):
        x, y, _ = at_angle(3.45, deg, 0)
        rbox((0.4, 0.4, 1.2), (x, y, P + 0.6), "steel", 0.14)
        octa(0.28, (x, y, P + 1.75), "glow")
    rail(2.7, grips=True, role="pearl")
    blast((2.2, 1.5), "pearl", rings=2, ducts=3, duct="pearl", reach=3.8)
    pilots(3.0, -0.3, P + 0.35, 0.15)


def tier6():
    """The top: the floating platform with a gold rim, three rings round the rider (a gold
    standing ring, a pearl waist ring, a tilted ring), a crown of six pylons with crystals, a halo
    over the head and gold exhaust ducts."""
    floating_platform(4.1, 2.5, "gold")
    ring(4.12, 0.09, (0, 0, P - 0.12), "gold")
    ring(3.9, 0.08, (0, 0, P - 0.3), "glow")
    ring(3.62, 0.05, (0, 0, P + 0.02), "glow")
    cz = P + 3.2
    turn = (math.radians(90), 0, 0)
    ring(3.3, 0.26, (0, 0.2, cz), "gold", rotation=turn, keep=lambda x, y, z: y > -3.15)
    ring(3.3, 0.07, (0, -0.07, cz), "glow", rotation=turn, keep=lambda x, y, z: y > -3.15)
    ring(3.1, 0.2, (0, 0, P + 2.0), "pearl", keep=lambda x, y, z: y > -2.0)
    ring(3.1, 0.06, (0, 0, P + 2.22), "glow", keep=lambda x, y, z: y > -2.0)
    # The tilted third ring leans back: the camera behind never sees it edge-on.
    ring(3.55, 0.12, (0, 0.2, cz), "pearl", rotation=(math.radians(90), math.radians(55), 0), keep=lambda x, y, z: y > -3.4)
    for side in (-1, 1):
        rbox((1.0, 1.0, 0.7), (side * 3.15, 0.2, P + 0.35), "dark", 0.22)
        rbox((0.32, 0.32, 1.5), (side * 3.15, 0.2, P + 1.3), "gold", 0.1)
    rbox((0.5, 1.0, 0.32), (0, 0.75, P + 4.4), "dark", 0.12)
    rbox((0.3, 0.3, cz + 3.3 - P - 4.4), (0, 0.55, (P + 4.4 + cz + 3.3) / 2), "gold", 0.1)
    ring(0.9, 0.08, (0, 0.1, P + 6.0), "glow")  # the halo over the head
    for deg in (150, -150, 90, -90, 30, -30):
        x, y, _ = at_angle(3.75, deg, 0)
        rbox((0.42, 0.42, 1.5), (x, y, P + 0.75), "pearl", 0.15)
        cyl(0.3, 0.12, (x, y, P + 1.55), "gold", vertices=24)
        octa(0.3, (x, y, P + 2.2), "glow")
    rail(2.7, grips=True, role="gold")
    blast((2.3, 1.6), "gold", rings=3, ducts=3, duct="gold", reach=4.1)
    pilots(3.15, -0.35, P + 0.35, 0.15)


# Each tier: its first trainer level, its name (for the concepts), its builder, the radius of the
# solid platform (its widest disc) and of the level dial's lamps on its top. The levels and radii
# are the game's too: BayLooks.STAND_TIERS, keep them in step.
TIERS = [
    {"from": 0, "name": "Рама", "build": tier1, "radius": 3.0, "dial": 2.75},
    {"from": 3, "name": "Стенд", "build": tier2, "radius": 3.45, "dial": 2.85},
    {"from": 6, "name": "Испытательный стенд", "build": tier3, "radius": 3.65, "dial": 3.0},
    {"from": 9, "name": "Ускоритель", "build": tier4, "radius": 3.85, "dial": 3.15},
    {"from": 12, "name": "Гироскоп", "build": tier5, "radius": 3.8, "dial": 3.4},
    {"from": 15, "name": "Звёздный стенд", "build": tier6, "radius": 4.1, "dial": 3.7},
]

# The level dial (BayLooks.STAND_DIAL): this many lamps over this arc (degrees), its gap in front
# where the rider steps off; a lamp's size (across, along the rim, up).
DIAL_LAMPS = 15
DIAL_ARC = 300
DIAL_LAMP = (0.32, 0.16, 0.06)


def dial_spots(radius):
    """Where the dial's lamps stand (x, y, degrees from straight behind), first to last."""
    spots = []
    for i in range(DIAL_LAMPS):
        deg = 180 + DIAL_ARC / 2 - DIAL_ARC * (i + 0.5) / DIAL_LAMPS
        x, y, _ = at_angle(radius, deg, 0)
        spots.append((x, y, deg))
    return spots


def build(tier):
    """Builds tier `tier` (1-based) at the origin; returns its new objects."""
    before = set(bpy.data.objects)
    TIERS[tier - 1]["build"]()
    return [obj for obj in bpy.data.objects if obj not in before]
