# The aliens as sleek sci-fi robot pets (decision 074): a ceramic shell, a dark visor with glowing
# eyes, glowing seams and a living core. Six families, each in its own shell; the zone decides the
# finish and what lives inside; the tier adds the outfit (decision 073's ladder).
#
# A builder draws the pet at base point (x, 0, z) facing -Y in a zone theme and returns anchors:
#   shells — the ceramic parts (a legendary turns them gold);
#   top    — where the halo goes; center, radius — for effects round it; width — the tier ring.

import math

import bpy
import real
from mathutils import Vector

GOLD = (1.0, 0.72, 0.18)
TIER_COLORS = [(0.7, 0.72, 0.78), (0.35, 0.95, 0.45), (0.25, 0.6, 1.0), (0.75, 0.3, 1.0), (1.0, 0.72, 0.15)]


# --- Zone themes --------------------------------------------------------------------------------


def _ceramic(color, wear=0.0):
    """Glossy ceramic; `wear` darkens it in patches, like a scuffed hull."""
    if wear <= 0:
        return real.gloss("Ceramic", color, 0.2)
    return real.chitin("Ceramic", color, tuple(c * (1 - wear) for c in color), 0.0)


THEMES = {
    # Debris Belt: scuffed orange ceramic over a white hull, cyan eyes.
    "debris": {"shell": lambda: _ceramic((0.9, 0.84, 0.76)), "accent_shell": lambda: _ceramic((1.0, 0.5, 0.16), 0.45),
               "accent": (1.0, 0.55, 0.2), "eyes": (0.3, 0.95, 1.0),
               "core": lambda: real.glow("Core", (1.0, 0.5, 0.15), 5.0)},
    # Ice Rings: frosted white-blue ceramic, a crystal core, cyan light.
    "ice": {"shell": lambda: real.frost("Ceramic", (0.68, 0.86, 1.0)), "accent_shell": lambda: real.crystal("Glass", (0.75, 0.92, 1.0), 0.1),
            "accent": (0.4, 0.9, 1.0), "eyes": (0.5, 0.95, 1.0),
            "core": lambda: real.glow("Core", (0.35, 0.85, 1.0), 5.0)},
    # Red Nebula: white ceramic with red trim, living red slime inside, warm yellow eyes.
    "nebula": {"shell": lambda: _ceramic((1.0, 0.86, 0.86)), "accent_shell": lambda: _ceramic((0.95, 0.2, 0.25)),
               "accent": (1.0, 0.3, 0.35), "eyes": (1.0, 0.85, 0.3),
               "core": lambda: real.glow("Core", (1.0, 0.18, 0.3), 4.0)},
    # Event Horizon: black ceramic, a nebula behind glass, violet light.
    "horizon": {"shell": lambda: real.gloss("Ceramic", (0.05, 0.05, 0.07), 0.15), "accent_shell": lambda: real.gloss("Trim", (0.25, 0.15, 0.4), 0.2),
                "accent": (0.75, 0.45, 1.0), "eyes": (0.8, 0.55, 1.0),
                "core": lambda: real.nebula("Core", (0.05, 0.02, 0.15), (0.35, 0.15, 0.65), (0.6, 0.85, 1.0), 8.0)},
}


# --- Parts --------------------------------------------------------------------------------------


def _smooth(obj, levels=1):
    if levels:
        mod = obj.modifiers.new("Subdivision", "SUBSURF")
        mod.levels = mod.render_levels = levels
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def sphere(location, scale, mat, segments=32, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = scale
    return real.assign(_smooth(obj, 0), mat)


def cylinder(location, radius, depth, mat, rotation=(0, 0, 0), vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = min(radius, depth) * 0.3
    bevel.segments = 4
    return real.assign(_smooth(obj, 0), mat)


def torus(location, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=location, major_radius=major, minor_radius=minor, rotation=rotation, major_segments=64, minor_segments=16)
    return real.assign(_smooth(bpy.context.active_object, 0), mat)


def pill(location, size, mat, rotation=(0, 0, 0), roundness=0.8):
    """A rounded box: a hull panel, a claw jaw, a fin."""
    bpy.ops.mesh.primitive_cube_add(location=location, scale=size, rotation=rotation)
    obj = bpy.context.active_object
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = min(size) * roundness
    bevel.segments = 6
    bevel.limit_method = "NONE"
    return real.assign(_smooth(obj, 0), mat)


def visor(location, width, height, eyes, rotation=(0, 0, 0)):
    """The dark visor with two glowing eye shapes."""
    x, y, z = location
    pill((x, y, z), (width, 0.07, height), real.gloss("Visor", (0.015, 0.02, 0.03), 0.04), rotation)
    for side in (-1, 1):
        sphere((x + side * width * 0.42, y - 0.075, z + height * 0.05), (width * 0.17, 0.02, height * 0.48), real.glow("EyeLight", eyes, 10.0), 24)


def glow(color, strength=6.0):
    return real.glow("Seam", color, strength)


# --- Families -----------------------------------------------------------------------------------


def slime(x, z, theme):
    shell = theme["shell"]()
    base = cylinder((x, 0, z + 0.25), 0.75, 0.4, shell, vertices=48)
    torus((x, 0, z + 0.47), 0.72, 0.035, glow(theme["accent"]))
    core = real.blob([(0, 0, 0.0, 0.55), (0, 0.02, 0.4, 0.32)], theme["core"](), (x, 0, z + 0.9))
    dome = sphere((x, 0, z + 1.0), (0.78, 0.78, 0.9), real.crystal("Dome", (0.9, 0.97, 1.0)), 48)
    visor((x, -0.72, z + 1.0), 0.42, 0.18, theme["eyes"])
    feet = [pill((x + side * 0.55, -0.15, z + 0.1), (0.18, 0.28, 0.1), theme["accent_shell"]()) for side in (-1, 1)]
    return {"shells": [base] + feet, "top": (x, 0, z + 1.95), "center": (x, 0, z + 0.9), "radius": 0.9, "width": 1.1}


def crab(x, z, theme):
    shell_mat = theme["shell"]()
    shell = sphere((x, 0, z + 0.85), (1.0, 0.8, 0.48), shell_mat, 48)
    plate = sphere((x, 0.08, z + 1.08), (0.72, 0.55, 0.3), theme["accent_shell"](), 48)
    torus((x, 0, z + 0.85), 0.98, 0.025, glow(theme["accent"]), (0, 0, 0))
    visor((x, -0.74, z + 0.88), 0.5, 0.13, theme["eyes"], (math.radians(-8), 0, 0))
    joint = real.gloss("Joint", (0.1, 0.11, 0.13), 0.25)
    shells = [shell]
    for side in (-1, 1):
        # Short sturdy legs: a thick thigh out to the side, a shin down to a glowing foot.
        for y in (0.3, 0.0, -0.3):
            sphere((x + side * 0.9, y, z + 0.72), (0.13, 0.13, 0.13), joint, 16)
            upper = cylinder((x + side * 1.08, y, z + 0.78), 0.09, 0.38, shell_mat, (0, math.radians(side * -70), 0))
            sphere((x + side * 1.25, y, z + 0.8), (0.11, 0.11, 0.11), joint, 16)
            lower = cylinder((x + side * 1.3, y, z + 0.45), 0.08, 0.6, shell_mat, (0, math.radians(side * 10), 0))
            sphere((x + side * 1.34, y, z + 0.12), (0.09, 0.09, 0.07), glow(theme["accent"], 8.0), 12)
            shells += [upper, lower]
        # Big claws held up in front.
        sphere((x + side * 0.8, -0.55, z + 0.88), (0.13, 0.13, 0.13), joint, 16)
        arm = cylinder((x + side * 0.98, -0.78, z + 1.0), 0.1, 0.42, shell_mat, (math.radians(-55), math.radians(side * -40), 0))
        claw = sphere((x + side * 1.15, -1.05, z + 1.15), (0.36, 0.4, 0.32), shell_mat, 32)
        pill((x + side * 1.17, -1.48, z + 1.28), (0.12, 0.24, 0.08), theme["accent_shell"](), (math.radians(-15), 0, 0))
        pill((x + side * 1.15, -1.44, z + 1.0), (0.1, 0.2, 0.07), shell_mat, (math.radians(15), 0, 0))
        torus((x + side * 1.15, -1.05, z + 1.15), 0.3, 0.025, glow(theme["accent"]), (math.radians(90), 0, 0))
        shells += [arm, claw]
    return {"shells": shells, "top": (x, 0.1, z + 1.75), "center": (x, 0, z + 0.85), "radius": 1.1, "width": 1.65}


def worm(x, z, theme):
    shell_mat = theme["shell"]()
    path = [(0.95, 1.1, 0.28, 0.24), (0.7, 0.78, 0.33, 0.3), (0.45, 0.45, 0.42, 0.35), (0.2, 0.15, 0.58, 0.4)]
    shells = []
    previous = None
    for px, py, pz, r in path:
        segment = sphere((x + px, py, z + pz), (r, r, r), shell_mat, 32)
        sphere((x + px, py - r * 0.55, z + pz + r * 0.2), (r * 0.42, r * 0.3, r * 0.42), theme["core"](), 24)
        shells.append(segment)
        if previous:
            mid = Vector(((previous[0] + px) / 2 + x, (previous[1] + py) / 2, (previous[2] + pz) / 2 + z))
            direction = Vector((px - previous[0], py - previous[1], pz - previous[2]))
            ring = torus(tuple(mid), r * 0.75, 0.035, glow(theme["accent"]))
            ring.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
        previous = (px, py, pz)
    head = sphere((x, -0.1, z + 1.05), (0.58, 0.55, 0.55), shell_mat, 48)
    pill((x, 0.02, z + 1.5), (0.3, 0.22, 0.08), theme["accent_shell"]())
    visor((x, -0.6, z + 1.08), 0.36, 0.13, theme["eyes"], (math.radians(-5), 0, 0))
    for side in (-1, 1):
        cylinder((x + side * 0.2, -0.05, z + 1.65), 0.02, 0.35, shell_mat, (0, math.radians(side * 15), 0))
        sphere((x + side * 0.25, -0.05, z + 1.83), (0.05, 0.05, 0.05), glow(theme["accent"], 9.0), 12)
    return {"shells": shells + [head], "top": (x, -0.1, z + 2.05), "center": (x + 0.3, 0.3, z + 0.75), "radius": 0.95, "width": 1.35}


def ray(x, z, theme):
    """A sleek flying drone-manta, hovering over a glow."""
    shell_mat = theme["shell"]()
    lift = 0.45
    body = sphere((x, 0.05, z + 0.8 + lift), (0.62, 0.75, 0.32), shell_mat, 48)
    shells = [body]
    for side in (-1, 1):
        wing = sphere((x + side * 0.95, 0.25, z + 0.85 + lift), (0.85, 0.55, 0.1), shell_mat, 48, (0, math.radians(side * -12), math.radians(side * -12)))
        tip = pill((x + side * 1.55, 0.45, z + 1.0 + lift), (0.22, 0.12, 0.04), theme["accent_shell"](), (0, math.radians(side * -25), math.radians(side * -20)))
        torus((x + side * 0.95, 0.25, z + 0.85 + lift), 0.5, 0.015, glow(theme["accent"]), (0, math.radians(side * -12), 0))
        shells.append(wing)
    sphere((x, 0.15, z + 1.0 + lift), (0.32, 0.4, 0.14), theme["core"](), 32)
    visor((x, -0.68, z + 0.85 + lift), 0.32, 0.1, theme["eyes"], (math.radians(-12), 0, 0))
    cylinder((x, 0.85, z + 0.78 + lift), 0.15, 0.25, real.gloss("Engine", (0.1, 0.11, 0.13), 0.3), (math.radians(90), 0, 0))
    sphere((x, 1.0, z + 0.78 + lift), (0.12, 0.05, 0.12), glow(theme["accent"], 12.0), 24)
    sphere((x, 0.1, z + 0.12), (0.7, 0.55, 0.02), real.aura("Hover", theme["accent"], 3.0, 0.3), 32)
    return {"shells": shells, "top": (x, 0.05, z + 1.6 + lift), "center": (x, 0.1, z + 0.85 + lift), "radius": 1.2, "width": 1.75}


def drone(x, y, z, size, theme, shell_mat, main):
    body = sphere((x, y, z), (0.55 * size, 0.5 * size, 0.5 * size), shell_mat, 32)
    pill((x, y + 0.1 * size, z + 0.38 * size), (0.22 * size, 0.18 * size, 0.06 * size), theme["accent_shell"]())
    visor((x, y - 0.46 * size, z + 0.03 * size), 0.3 * size, 0.11 * size, theme["eyes"])
    for side in (-1, 1):
        sphere((x + side * 0.55 * size, y + 0.15 * size, z + 0.35 * size), (0.4 * size, 0.2 * size, 0.03 * size),
               real.iridescent("Wing", (0.8, 0.9, 1.0), transmission=0.85), 24, (0, math.radians(side * -20), 0))
    sphere((x, y, z - 0.5 * size), (0.15 * size, 0.15 * size, 0.06 * size), glow(theme["accent"], 10.0), 16)
    return body


def swarm(x, z, theme):
    shell_mat = theme["shell"]()
    main = drone(x, 0, z + 1.0, 1.25, theme, shell_mat, True)
    small = [drone(x - 1.05, 0.2, z + 1.75, 0.5, theme, shell_mat, False), drone(x + 1.0, 0.1, z + 0.55, 0.45, theme, shell_mat, False)]
    return {"shells": [main] + small, "top": (x, 0, z + 1.8), "center": (x, 0, z + 1.0), "radius": 1.0, "width": 1.25}


def whale(x, z, theme):
    """A chubby little whale-sub: a porthole visor, fins, a glowing thruster."""
    shell_mat = theme["shell"]()
    body = sphere((x, 0.15, z + 1.0), (0.95, 1.2, 0.85), shell_mat, 48)
    belly = sphere((x, -0.15, z + 0.72), (0.75, 0.85, 0.5), theme["accent_shell"](), 48)
    torus((x, 0.15, z + 1.0), 0.93, 0.025, glow(theme["accent"]), (math.radians(90), 0, math.radians(90)))
    # A round porthole of a visor with the core glowing behind it.
    torus((x, -0.98, z + 1.12), 0.36, 0.06, real.chrome("Rim", (0.7, 0.72, 0.76)), (math.radians(90), 0, 0))
    sphere((x, -0.95, z + 1.12), (0.34, 0.08, 0.34), real.gloss("Glass", (0.015, 0.02, 0.03), 0.04), 32)
    for side in (-1, 1):
        sphere((x + side * 0.13, -1.03, z + 1.14), (0.06, 0.02, 0.1), real.glow("EyeLight", theme["eyes"], 10.0), 16)
        pill((x + side * 0.95, -0.05, z + 0.6), (0.32, 0.18, 0.06), shell_mat, (0, math.radians(side * 25), 0))
        pill((x + side * 0.35, 1.45, z + 1.55), (0.3, 0.14, 0.06), theme["accent_shell"](), (math.radians(30), math.radians(side * 20), 0))
    sphere((x, 0.35, z + 1.6), (0.4, 0.45, 0.12), theme["core"](), 32)
    cylinder((x, 1.35, z + 1.1), 0.22, 0.25, real.gloss("Engine", (0.1, 0.11, 0.13), 0.3), (math.radians(90), 0, 0))
    sphere((x, 1.5, z + 1.1), (0.16, 0.05, 0.16), glow(theme["accent"], 12.0), 24)
    return {"shells": [body], "top": (x, 0.15, z + 2.1), "center": (x, 0.15, z + 1.0), "radius": 1.2, "width": 1.5}


FAMILIES = {"slime": slime, "crab": crab, "worm": worm, "ray": ray, "swarm": swarm, "whale": whale}


# --- Tier outfit --------------------------------------------------------------------------------


def tier_ring(x, z, width, tier):
    torus((x, 0, z + 0.03), width, 0.045 + 0.01 * tier, real.glow("TierRing", TIER_COLORS[tier], 1.5 + tier * 1.5))


def motes(info, color, count, strength=10.0):
    cx, cy, cz = info["center"]
    radius = info["radius"] + 0.55
    mat = real.glow("Mote", color, strength)
    for index in range(count):
        angle = index / count * math.tau + 0.3
        sphere((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius * 0.55, cz + 0.15 + 0.8 * math.sin(index * 1.7)), (0.04, 0.04, 0.04), mat, 10)


def build(family, zone, tier, x, z):
    """One pet at base point (x, 0, z): the family's shell in the zone's theme, in `tier`."""
    theme = THEMES[zone]
    info = FAMILIES[family](x, z, theme)
    tier_ring(x, z, info["width"], tier)
    if tier >= 3:
        motes(info, TIER_COLORS[tier], 8 if tier == 3 else 14)
    if tier == 4:
        gold = real.chrome("Gold", GOLD, 0.26)
        for shell in info["shells"]:
            real.assign(shell, gold)
        tx, ty, tz = info["top"]
        torus((tx, ty, tz + 0.2), 0.36, 0.035, real.glow("Halo", GOLD, 10.0), (math.radians(15), 0, 0))
    return info
