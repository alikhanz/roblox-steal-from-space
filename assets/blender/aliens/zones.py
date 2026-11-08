# Each zone's look and how a tier grows in it (decision 073). A zone gives the body's material
# per tier, the growths on the back per tier, the eyes' glow; the tier adds the shared effects:
# its ring, an aura shell and floating motes from epic up, a crest or halo and a ring of motes at
# legendary. The meteor variant is molten rock with lava cracks, embers and smoke.
#   Debris Belt  — biotech: a living body under armour plates, light panels, antennae;
#   Ice Rings    — crystal and ice;
#   Red Nebula   — living aliens: jelly and skin, frills, bioluminescence;
#   Event Horizon — cosmic matter: bodies of nebula, rings and moons.

import math

import bpy
import real

# The tiers in order (AlienConfig.TIERS) and each tier's colour for its ring, aura and motes.
TIERS = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
TIER_COLORS = [(0.7, 0.72, 0.78), (0.35, 0.95, 0.45), (0.25, 0.6, 1.0), (0.75, 0.3, 1.0), (1.0, 0.72, 0.15)]
GOLD = (1.0, 0.72, 0.18)


def lighter(color, amount=0.45):
    return tuple(c + (1 - c) * amount for c in color)


def darker(color, amount=0.35):
    return tuple(c * (1 - amount) for c in color)


def _place(obj, location, rotation=(0, 0, 0)):
    obj.location = location
    obj.rotation_euler = rotation
    return obj


def sphere(location, radius, mat, segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=location, radius=radius)
    obj = bpy.context.active_object
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return real.assign(obj, mat)


def spike(location, radius, length, mat, tilt=(0, 0, 0), sides=6):
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, depth=length, location=location, rotation=tilt)
    return real.assign(bpy.context.active_object, mat)


def plate(location, size, mat, tilt=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, scale=size, rotation=tilt)
    obj = bpy.context.active_object
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = min(size) * 0.6
    bevel.segments = 3
    return real.assign(obj, mat)


def fin(location, size, mat, tilt=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
    obj = bpy.context.active_object
    obj.scale = size
    obj.rotation_euler = tilt
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return real.assign(obj, mat)


def torus(location, major, minor, mat, tilt=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=location, major_radius=major, minor_radius=minor, rotation=tilt, major_segments=64, minor_segments=12)
    obj = bpy.context.active_object
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return real.assign(obj, mat)


def outward(point, center):
    """Tilts a growth at `point` to lean away from the body's middle."""
    dx, dy = point[0] - center[0], point[1] - center[1]
    return (math.radians(-dy * 28), math.radians(dx * 28), 0)


# --- Zone looks ---------------------------------------------------------------------------------


def biotech(info, color, tier):
    body = [
        real.chitin("Chitin", color, darker(color, 0.75)),
        real.chitin("Chitin", lighter(color, 0.15), darker(color, 0.8), 0.4),
        real.veined("Veins", darker(color, 0.25), (0.3, 0.9, 1.0), 3.0),
        real.veined("Veins", darker(color, 0.35), TIER_COLORS[3], 4.0),
        real.veined("Veins", (0.08, 0.07, 0.1), GOLD, 6.0),
    ][tier]
    plates = real.chrome("Gold", GOLD) if tier == 4 else real.armor("Armor", (0.48, 0.52, 0.58))
    count = [0, 2, 4, 6, 8][tier]
    center = info["center"]
    for point in info["back"][:count]:
        plate(point, (0.2, 0.16, 0.05), plates, outward(point, center))
    if tier >= 2:
        tx, ty, tz = info["top"]
        cyl = bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=0.6, location=(tx + 0.2, ty + 0.15, tz + 0.25))
        real.assign(bpy.context.active_object, real.armor("Mast", (0.4, 0.42, 0.46)))
        sphere((tx + 0.2, ty + 0.15, tz + 0.58), 0.06, real.glow("Beacon", (1.0, 0.35, 0.2) if tier < 4 else GOLD, 8.0))
    if tier >= 3:
        for point in info["back"][:3]:
            px, py, pz = point
            plate((px, py - 0.05, pz + 0.06), (0.12, 0.02, 0.012), real.glow("Panel", TIER_COLORS[tier], 6.0), outward(point, center))
    if tier == 4:
        cx, cy, cz = info["center"]
        sphere((cx, cy + 0.35, cz + 0.55), 0.18, real.glow("Core", GOLD, 10.0), 24)
    return body


def crystal(info, color, tier):
    # Crystal from the start (user: "a crystal worm should be crystal"); it glows more each tier.
    body = [
        real.crystal("Crystal", color, 0.03),
        real.crystal("Crystal", color, 0.12),
        real.crystal("Crystal", lighter(color, 0.1), 0.25),
        real.crystal("Crystal", lighter(color, 0.15), 0.45),
        real.iridescent("Prism", lighter(color, 0.3), transmission=0.85, glow=0.4),
    ][tier]
    # A glowing heart inside from the start, so the clear body never reads as empty.
    sphere(info["center"], 0.18 + 0.05 * tier, real.glow("Heart", (0.45, 0.85, 1.0), 4.0 + tier * 2), 24)
    shard = real.iridescent("Shard", lighter(color, 0.4), transmission=0.9) if tier == 4 else real.crystal("Shard", lighter(color, 0.4), 0.15 * tier)
    count = [0, 2, 4, 6, 8][tier]
    length = [0, 0.3, 0.42, 0.55, 0.75][tier]
    center = info["center"]
    for index, point in enumerate(info["back"][:count]):
        size = length * (1.0 if index % 3 == 0 else 0.7)
        px, py, pz = point
        spike((px, py, pz + size / 2), 0.09 + 0.02 * tier, size, shard, outward(point, center), 5)
    if tier == 4:
        cx, cy, cz = info["center"]
        for index in range(7):
            angle = index / 7 * math.tau
            spike((cx + math.cos(angle) * 1.7, cy + math.sin(angle) * 1.1, cz + 0.9 + 0.3 * math.sin(angle * 2)), 0.07, 0.3, shard, (angle, angle * 0.5, 0), 4)
    return body


def living(info, color, tier):
    glow = lighter(color, 0.5)
    body = [
        real.jelly("Jelly", color, 0.05),
        real.jelly("Jelly", color, 0.2),
        real.veined("Bio", color, glow, 2.5),
        real.veined("Bio", color, TIER_COLORS[3], 4.0),
        real.iridescent("Opal", lighter(color, 0.25), transmission=0.3, glow=0.6),
    ][tier]
    frill = real.veined("Frill", darker(color, 0.1), glow if tier < 4 else GOLD, 1.5 + tier)
    count = [0, 2, 3, 5, 7][tier]
    center = info["center"]
    for index, point in enumerate(info["back"][:count]):
        px, py, pz = point
        height = 0.18 + 0.06 * tier
        fin((px, py, pz + height * 0.4), (0.06, 0.18 + 0.03 * tier, height), frill, outward(point, center))
    if tier >= 2:
        for point in info["back"][:4]:
            px, py, pz = point
            sphere((px, py - 0.18, pz - 0.12), 0.045, real.glow("Spot", glow, 6.0))
    if tier == 4:
        tx, ty, tz = info["top"]
        for index, lean in enumerate((-30, -12, 0, 12, 30)):
            spike((tx + lean / 60, ty, tz + 0.3), 0.06, 0.6 - abs(lean) / 100, real.glow("Crest", GOLD, 5.0), (0, math.radians(lean), 0), 8)
    return body


def cosmic(info, color, tier):
    deep, mid, bright = darker(color, 0.7), color, lighter(color, 0.55)
    if tier == 4:
        deep, mid, bright = (0.03, 0.01, 0.08), (0.45, 0.15, 0.6), (1.0, 0.75, 0.45)
    body = real.nebula("Nebula", deep, mid, bright, 3.0 + tier * 2.5)
    cx, cy, cz = info["center"]
    radius = info["radius"]
    star = real.glow("Star", (1.0, 1.0, 1.0), 12.0)
    if tier >= 1:
        for index in range(3 + tier * 2):
            angle = index * 2.4
            sphere((cx + math.cos(angle) * (radius + 0.5), cy - 0.4, cz + 0.6 + math.sin(angle) * 0.7), 0.035, star, 8)
    # Rings lie nearly flat round the body, like orbits.
    if tier >= 2:
        torus((cx, cy, cz + 0.15), radius + 0.45, 0.025, real.glow("Ring", bright, 4.0), (math.radians(14), math.radians(10), 0))
    if tier >= 3:
        torus((cx, cy, cz + 0.3), radius + 0.75, 0.018, real.glow("Ring", TIER_COLORS[tier], 4.0), (math.radians(-18), math.radians(22), 0))
        sphere((cx + radius + 0.7, cy - 0.3, cz + 0.45), 0.14, real.chitin("Moon", (0.7, 0.68, 0.62), (0.3, 0.28, 0.25)), 24)
    if tier == 4:
        disk = torus((cx, cy, cz + 0.05), radius + 0.55, 0.12, real.glow("Disk", (1.0, 0.6, 0.25), 6.0), (math.radians(8), 0, 0))
        disk.scale = (1, 1, 0.25)
        tx, ty, tz = info["top"]
        sphere((tx, ty, tz + 0.45), 0.22, real.gloss("Void", (0.0, 0.0, 0.0), 0.02), 32)
        torus((tx, ty, tz + 0.45), 0.34, 0.03, real.glow("Halo", GOLD, 8.0), (math.radians(20), 0, 0))
    return body


ZONES = {
    "biotech": (biotech, (0.3, 0.95, 1.0)),
    "crystal": (crystal, (0.55, 0.95, 1.0)),
    "living": (living, (0.75, 1.0, 0.35)),
    "cosmic": (cosmic, (0.8, 0.6, 1.0)),
}


# --- Tier effects -------------------------------------------------------------------------------


def tier_ring(x, z, width, tier):
    torus((x, 0, z + 0.03), width, 0.05 + 0.012 * tier, real.glow("TierRing", TIER_COLORS[tier], 1.0 + tier * 1.5))


def aura_shell(body, color, strength, scale=1.1):
    shell = body.copy()
    shell.data = body.data.copy()
    bpy.context.scene.collection.objects.link(shell)
    bpy.context.view_layer.update()
    center = sum((shell.matrix_world @ v.co for v in shell.data.vertices), shell.matrix_world.translation * 0) / max(1, len(shell.data.vertices))
    for vertex in shell.data.vertices:
        world = shell.matrix_world @ vertex.co
        vertex.co = shell.matrix_world.inverted() @ (center + (world - center) * scale)
    shell.modifiers.clear()
    return real.assign(shell, real.aura("Aura", color, strength))


def motes(info, color, count, spread=0.5, strength=8.0):
    cx, cy, cz = info["center"]
    radius = info["radius"] + spread
    mat = real.glow("Mote", color, strength)
    for index in range(count):
        angle = index / count * math.tau + 0.4
        height = cz + 0.2 + 0.9 * math.sin(index * 1.7)
        sphere((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius * 0.6, height), 0.04 + 0.015 * (index % 3), mat, 10)


def mote_ring(info, color):
    cx, cy, cz = info["center"]
    radius = info["radius"] + 0.85
    mat = real.glow("Mote", color, 10.0)
    for index in range(18):
        angle = index / 18 * math.tau
        sphere((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius * 0.45, cz + 1.1 + math.sin(angle) * radius * 0.2), 0.045, mat, 10)


def build_tier(family, zone, color, tier, x, z):
    """Draws one alien at base point (x, 0, z) in `tier` (0 common .. 4 legendary)."""
    look, iris = ZONES[zone]
    # The body first in a stand-in material, then the zone dresses it.
    placeholder = real.glow("Tmp", color, 0.0)
    info = family(x, z, placeholder, iris if tier < 4 else GOLD)
    real.assign(info["body"], look(info, color, tier))
    tier_ring(x, z, info["width"], tier)
    if tier >= 3:
        aura_shell(info["body"], TIER_COLORS[tier], 1.5 + tier * 0.5)
        motes(info, TIER_COLORS[tier], 6 if tier == 3 else 10)
    if tier == 4:
        mote_ring(info, GOLD)
    return info


def build_meteor(family, color, x, z):
    """The meteor variant: molten rock, lava cracks, embers rising and a wisp of smoke."""
    info = family(x, z, real.molten("Molten"), (1.0, 0.55, 0.15))
    tier_ring(x, z, info["width"], 2)
    motes(info, (1.0, 0.5, 0.1), 9, 0.2, 12.0)
    tx, ty, tz = info["top"]
    smoke = real.aura("Smoke", (0.18, 0.16, 0.16), 0.0, 0.14)
    for index, (dx, dz, r) in enumerate(((0.0, 0.3, 0.16), (0.12, 0.58, 0.2), (-0.06, 0.88, 0.24))):
        sphere((tx + dx, ty + 0.2, tz + dz), r, smoke, 16)
    return info
