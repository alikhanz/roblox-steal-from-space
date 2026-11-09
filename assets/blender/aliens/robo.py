# The aliens as sleek sci-fi robot pets (decision 074): a ceramic shell, a dark visor with glowing
# eyes, glowing seams and a living core. Six families, each in its own shell; the zone decides the
# finish and what lives inside; the tier adds the outfit (decision 073's ladder).
#
# A builder draws the pet at base point (x, 0, z) facing -Y in a zone theme and returns anchors:
#   shells — the ceramic parts (a legendary turns them gold);
#   top    — where the halo goes; center, radius — for effects round it; width — the tier ring.

import contextlib
import functools
import math

import bpy
import real
from mathutils import Euler, Matrix, Vector

GOLD = (1.0, 0.72, 0.18)
TIER_COLORS = [(0.7, 0.72, 0.78), (0.35, 0.95, 0.45), (0.25, 0.6, 1.0), (0.75, 0.3, 1.0), (1.0, 0.72, 0.15)]
# How finely round shapes are divided: 1 for renders; an export for the web viewer lowers it to
# keep hundreds of models small.
DETAIL = 1.0


def _detail(count, least=6):
    return max(least, int(round(count * DETAIL)))


# --- Roles --------------------------------------------------------------------------------------
#
# Every part is tagged with what it is for (obj["role"]), so a game export can treat parts apart:
# move them (wings flap, a rotor spins, drones and rocks circle, rays turn), or drop the ones that
# only stand in for effects ("fx": motes, sparkles, embers, tails) and play particles there instead.
# Parts are "body" unless built inside a role; a glowing core is "core".

_ROLES = ["body"]


@contextlib.contextmanager
def role(name):
    _ROLES.append(name)
    try:
        yield
    finally:
        _ROLES.pop()


def in_role(name):
    """Decorator: everything the function builds is in `name`."""
    def wrap(function):
        @functools.wraps(function)
        def run(*args, **kwargs):
            with role(name):
                return function(*args, **kwargs)
        return run
    return wrap


def _tag(obj):
    material = obj.data.materials[0].name if obj.data.materials and obj.data.materials[0] else ""
    obj["role"] = "core" if _ROLES[-1] == "body" and material.startswith("Core") else _ROLES[-1]
    return obj


# --- Zone finishes and kind colours -------------------------------------------------------------
#
# A zone decides the finish (what the hull is made of); a kind decides the colours on it. So all
# kinds of a zone share a material family, and each still has colours of its own.


def _ceramic(color, wear=0.0):
    """Glossy ceramic; `wear` darkens it in patches, like a scuffed hull."""
    if wear <= 0:
        return real.gloss("Ceramic", color, 0.2)
    return real.chitin("Ceramic", color, tuple(c * (1 - wear) for c in color), 0.0)


ZONES = {
    # Debris Belt: scuffed ceramic, plain and sturdy.
    "debris": {"shell": lambda c: _ceramic(c), "trim": lambda c: _ceramic(c, 0.45),
               "core": lambda c: real.glow("Core", c, 1.8),
               "look": {"shell": (0.9, 0.84, 0.76), "trim": (1.0, 0.5, 0.16), "glow": (1.0, 0.55, 0.2), "eyes": (0.3, 0.95, 1.0), "core": (1.0, 0.5, 0.15)}},
    # Ice Rings: frosted ceramic and clear glass.
    "ice": {"shell": lambda c: real.frost("Ceramic", c), "trim": lambda c: real.crystal("Glass", c, 0.1),
            "core": lambda c: real.glow("Core", c, 1.8),
            "look": {"shell": (0.68, 0.86, 1.0), "trim": (0.75, 0.92, 1.0), "glow": (0.4, 0.9, 1.0), "eyes": (0.5, 0.95, 1.0), "core": (0.35, 0.85, 1.0)}},
    # Red Nebula: lacquered ceramic over living light.
    "nebula": {"shell": lambda c: real.gloss("Ceramic", c, 0.12), "trim": lambda c: real.iridescent("Trim", c),
               "core": lambda c: real.glow("Core", c, 1.8),
               "look": {"shell": (1.0, 0.86, 0.86), "trim": (0.95, 0.2, 0.25), "glow": (1.0, 0.3, 0.35), "eyes": (1.0, 0.85, 0.3), "core": (1.0, 0.18, 0.3)}},
    # Event Horizon: black mirror ceramic, a nebula behind glass.
    "horizon": {"shell": lambda c: real.gloss("Ceramic", c, 0.15), "trim": lambda c: real.gloss("Trim", c, 0.2),
                "core": lambda c: real.nebula("Core", (0.05, 0.02, 0.15), c, (0.6, 0.85, 1.0), 8.0),
                "look": {"shell": (0.05, 0.05, 0.07), "trim": (0.25, 0.15, 0.4), "glow": (0.75, 0.45, 1.0), "eyes": (0.8, 0.55, 1.0), "core": (0.35, 0.15, 0.65)}},
}


def theme(zone, look=None):
    """The material makers for a pet: the zone's finishes in the kind's colours."""
    finish = ZONES[zone]
    colours = dict(finish["look"])
    colours.update(look or {})
    # How a kind wears its guardian's palette: as is, with body and trim swapped (the second kind),
    # or with the body in candy metal (the rare kind, so its rarity shows).
    paint = colours.get("paint", "plain")
    if paint == "swap":
        colours["shell"], colours["trim"] = colours["trim"], colours["shell"]
    if colours.get("finish") == "glass":
        # A crystal kind is see-through, so its core shows inside the body.
        shell = lambda: shell_glass("Crystal", colours["shell"], 0.45)  # noqa: E731
    elif paint == "candy":
        shell = lambda: candy("Candy", colours["shell"])  # noqa: E731
    else:
        shell = lambda: finish["shell"](colours["shell"])  # noqa: E731
    return {
        "shell": shell,
        "accent_shell": lambda: finish["trim"](colours["trim"]),
        "accent": colours["glow"],
        "eyes": colours["eyes"],
        "core": lambda: finish["core"](colours["core"]),
        "colours": colours,
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
    bpy.ops.mesh.primitive_uv_sphere_add(segments=_detail(segments), ring_count=max(_detail(segments) // 2, 4), location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = scale
    return _tag(real.assign(_smooth(obj, 0), mat))


def gem(location, scale, mat, rotation=(0, 0, 0)):
    """A faceted crystal body: an icosphere without smoothing."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = scale
    return _tag(real.assign(obj, mat))


def cylinder(location, radius, depth, mat, rotation=(0, 0, 0), vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=_detail(vertices))
    obj = bpy.context.active_object
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = min(radius, depth) * 0.3
    bevel.segments = _detail(4, 1)
    return _tag(real.assign(_smooth(obj, 0), mat))


def torus(location, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=location, major_radius=major, minor_radius=minor, rotation=rotation, major_segments=_detail(64), minor_segments=_detail(16))
    return _tag(real.assign(_smooth(bpy.context.active_object, 0), mat))


def pill(location, size, mat, rotation=(0, 0, 0), roundness=0.8):
    """A rounded box: a hull panel, a claw jaw, a fin."""
    bpy.ops.mesh.primitive_cube_add(location=location, scale=size, rotation=rotation)
    obj = bpy.context.active_object
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = min(size) * roundness
    bevel.segments = _detail(6, 2)
    bevel.limit_method = "NONE"
    return _tag(real.assign(_smooth(obj, 0), mat))


def visor(location, width, height, eyes, rotation=(0, 0, 0)):
    """The dark visor with two glowing eye shapes."""
    x, y, z = location
    pill((x, y, z), (width, 0.07, height), real.gloss("Visor", (0.015, 0.02, 0.03), 0.04), rotation)
    for side in (-1, 1):
        sphere((x + side * width * 0.42, y - 0.075, z + height * 0.05), (width * 0.17, 0.02, height * 0.48), real.glow("EyeLight", eyes, 10.0), 24)


def candy(name, color):
    """Candy metal: a coloured metal under a clear lacquer, the rare kind's paint."""
    mat = real.chrome(name, color, 0.25)
    mat.node_tree.nodes.get("Principled BSDF").inputs["Coat Weight"].default_value = 1.0
    return mat


def shell_glass(name, color, alpha=0.22):
    """A thin glass shell (a dome, a porthole) as plain see-through gloss, not refraction: that
    is what a Roblox part with Transparency can show, and what lives inside stays visible."""
    mat, nodes, links, bsdf = real._principled(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.03
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Alpha"].default_value = alpha
    if hasattr(mat, "use_raytrace_refraction"):
        mat.use_raytrace_refraction = False
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    mat.diffuse_color = (*color, alpha)
    return mat


def glow(color, strength=6.0):
    return real.glow("Seam", color, strength)


# --- Families -----------------------------------------------------------------------------------
#
# Each family takes shape parameters `p`, so kinds of one family differ in silhouette, not only in
# colour: a tall test-tube slime and a wide royal one, a boxy crab and one with a single huge claw.


def slime(x, z, theme, p=None):
    """A slime in a glass dome on a ceramic base. p: w (width), h (height)."""
    p = p or {}
    w, h = p.get("w", 1.0), p.get("h", 1.0)
    shell = theme["shell"]()
    base = cylinder((x, 0, z + 0.25), 0.75 * w, 0.4, shell, vertices=48)
    torus((x, 0, z + 0.47), 0.72 * w, 0.035, glow(theme["accent"]))
    dome_z = z + 0.1 + 0.9 * h
    core = [(0, 0, 0.0, 0.72 * w), (0, 0.02, 0.42 * h, 0.45 * w)]
    if h > 1.2:
        core.append((0, 0.0, 0.85 * h, 0.26 * w))
    _tag(real.blob(core, theme["core"](), (x, 0, dome_z - 0.1), 0.045 / DETAIL))
    tint = tuple(0.75 + 0.25 * c for c in theme["colours"]["core"])
    sphere((x, 0, dome_z), (0.78 * w, 0.78 * w, 0.9 * h), shell_glass("Dome", tint), 48)
    visor((x, -0.72 * w, dome_z), 0.42 * min(w, 1.15), 0.18, theme["eyes"])
    feet = [pill((x + side * 0.55 * w, -0.15, z + 0.1), (0.18, 0.28, 0.1), theme["accent_shell"]()) for side in (-1, 1)]
    top = dome_z + 0.9 * h + 0.05
    return {"shells": [base] + feet, "top": (x, 0, top), "center": (x, 0, dome_z - 0.1), "radius": 0.9 * w, "width": 1.1 * w}


def crab(x, z, theme, p=None):
    """A crab. p: boxy (a blocky tank hull), claws (left, right sizes), legs (per side), w (width)."""
    p = p or {}
    w = p.get("w", 1.0)
    left, right = p.get("claws", (1.0, 1.0))
    legs = p.get("legs", 3)
    shell_mat = theme["shell"]()
    if p.get("boxy"):
        shell = pill((x, 0, z + 0.85), (1.0 * w, 0.75, 0.45), shell_mat, roundness=0.45)
        plate = pill((x, 0.08, z + 1.22), (0.7 * w, 0.5, 0.12), theme["accent_shell"](), roundness=0.6)
    else:
        shell = sphere((x, 0, z + 0.85), (1.0 * w, 0.8, 0.48), shell_mat, 48)
        plate = sphere((x, 0.08, z + 1.08), (0.72 * w, 0.55, 0.3), theme["accent_shell"](), 48)
    torus((x, 0, z + 0.85), 0.98 * w, 0.025, glow(theme["accent"]), (0, 0, 0))
    visor((x, -0.74, z + 0.88), 0.5, 0.13, theme["eyes"], (math.radians(-8), 0, 0))
    joint = real.gloss("Joint", (0.1, 0.11, 0.13), 0.25)
    shells = [shell, plate]
    spots = [0.3, 0.0, -0.3][:legs] if legs <= 3 else [0.36, 0.12, -0.12, -0.36]
    for side in (-1, 1):
        # Short sturdy legs: a thick thigh out to the side, a shin down to a glowing foot.
        for y in spots:
            hip = 0.9 * w
            sphere((x + side * hip, y, z + 0.72), (0.13, 0.13, 0.13), joint, 16)
            upper = cylinder((x + side * (hip + 0.18), y, z + 0.78), 0.09, 0.38, shell_mat, (0, math.radians(side * -70), 0))
            sphere((x + side * (hip + 0.35), y, z + 0.8), (0.11, 0.11, 0.11), joint, 16)
            lower = cylinder((x + side * (hip + 0.4), y, z + 0.45), 0.08, 0.6, shell_mat, (0, math.radians(side * 10), 0))
            sphere((x + side * (hip + 0.44), y, z + 0.12), (0.09, 0.09, 0.07), glow(theme["accent"], 8.0), 12)
            shells += [upper, lower]
        # Claws held up in front; a kind may grow one much bigger.
        size = left if side < 0 else right
        if size <= 0:
            continue
        cx = x + side * (0.8 * w + 0.35 * (size - 1))
        sphere((x + side * 0.8 * w, -0.55, z + 0.88), (0.13, 0.13, 0.13), joint, 16)
        arm = cylinder((x + side * (0.98 * w), -0.78, z + 1.0), 0.1, 0.42, shell_mat, (math.radians(-55), math.radians(side * -40), 0))
        claw = sphere((cx + side * 0.35, -1.05 - 0.15 * (size - 1), z + 1.15 + 0.2 * (size - 1)), (0.36 * size, 0.4 * size, 0.32 * size), shell_mat, 32)
        ccx, ccy, ccz = claw.location
        pill((ccx + side * 0.02, ccy - 0.43 * size, ccz + 0.13 * size), (0.12 * size, 0.24 * size, 0.08 * size), theme["accent_shell"](), (math.radians(-15), 0, 0))
        pill((ccx, ccy - 0.39 * size, ccz - 0.15 * size), (0.1 * size, 0.2 * size, 0.07 * size), shell_mat, (math.radians(15), 0, 0))
        torus((ccx, ccy, ccz), 0.3 * size, 0.025, glow(theme["accent"]), (math.radians(90), 0, 0))
        shells += [arm, claw]
    return {"shells": shells, "top": (x, 0.1, z + 1.75), "center": (x, 0, z + 0.85), "radius": 1.1 * w, "width": 1.65 * w}


def worm(x, z, theme, p=None):
    """A segmented worm rearing up. p: segments, r (thickness), faceted (crystal segments)."""
    p = p or {}
    count = p.get("segments", 4)
    rs = p.get("r", 1.0)
    faceted = p.get("faceted", False)
    shell_mat = theme["shell"]()
    shells = []
    previous = None
    for index in range(count):
        px = 0.2 + 0.24 * index + 0.06 * math.sin(index * 1.3)
        py = 0.15 + 0.3 * index
        pz = max(0.24, 0.58 - 0.11 * index)
        r = max(0.16, 0.4 - 0.045 * index) * rs
        if faceted:
            segment = gem((x + px, py, z + pz), (r * 1.1, r, r * 1.15), shell_mat, (0.3 * index, 0.5, 0.2 * index))
            sphere((x + px, py, z + pz), (r * 0.45,) * 3, theme["core"](), 16)
        else:
            segment = sphere((x + px, py, z + pz), (r, r, r), shell_mat, 32)
            sphere((x + px, py - r * 0.55, z + pz + r * 0.2), (r * 0.42, r * 0.3, r * 0.42), theme["core"](), 24)
        shells.append(segment)
        if previous and not faceted:
            mid = Vector(((previous[0] + px) / 2 + x, (previous[1] + py) / 2, (previous[2] + pz) / 2 + z))
            direction = Vector((px - previous[0], py - previous[1], pz - previous[2]))
            ring = torus(tuple(mid), r * 0.75, 0.035, glow(theme["accent"]))
            ring.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
        previous = (px, py, pz)
    head_r = 0.58 * min(rs, 1.25)
    head_z = z + 0.5 + head_r
    if faceted:
        head = gem((x, -0.1, head_z), (head_r * 1.05, head_r, head_r), shell_mat, (0.2, 0.4, 0.1))
    else:
        head = sphere((x, -0.1, head_z), (head_r, head_r * 0.95, head_r * 0.95), shell_mat, 48)
    pill((x, 0.02, head_z + head_r * 0.8), (0.3, 0.22, 0.08), theme["accent_shell"]())
    visor((x, -0.1 - head_r * 0.88, head_z + 0.03), 0.36 * head_r / 0.58, 0.13, theme["eyes"], (math.radians(-5), 0, 0))
    for side in (-1, 1):
        cylinder((x + side * 0.2, -0.05, head_z + head_r + 0.02), 0.02, 0.35, shell_mat, (0, math.radians(side * 15), 0))
        sphere((x + side * 0.25, -0.05, head_z + head_r + 0.2), (0.05, 0.05, 0.05), glow(theme["accent"], 9.0), 12)
    top = head_z + head_r + 0.45
    return {"shells": shells + [head], "top": (x, -0.1, top), "center": (x + 0.3, 0.3, z + 0.75), "radius": 0.95 * max(rs, 1.0), "width": 1.35 * max(rs, 1.0),
            "head": (x, -0.1, head_z), "head_r": head_r}


def ray(x, z, theme, p=None):
    """A flying drone-manta over a hover glow. p: span (wing size), droop (wing curl), tail."""
    p = p or {}
    span = p.get("span", 1.0)
    droop = p.get("droop", 12)
    shell_mat = theme["shell"]()
    lift = 0.45
    body = sphere((x, 0.05, z + 0.8 + lift), (0.62, 0.75, 0.32), shell_mat, 48)
    shells = [body]
    for side in (-1, 1):
        # An inner wing and an outer one curled up: the wing reads as a flexing fin, not a plank.
        inner = sphere((x + side * 0.85 * span, 0.2, z + 0.82 + lift), (0.75 * span, 0.55, 0.1), shell_mat, 48,
                       (0, math.radians(side * -droop * 0.4), math.radians(side * -14)))
        outer = sphere((x + side * 1.55 * span, 0.42, z + 1.0 + lift), (0.45 * span, 0.32, 0.07), shell_mat, 48,
                       (0, math.radians(side * -droop * 2.2), math.radians(side * -28)))
        pill((x + side * 1.9 * span, 0.58, z + 1.18 + lift), (0.16, 0.1, 0.035), theme["accent_shell"](),
             (0, math.radians(side * -droop * 2.6), math.radians(side * -32)))
        torus((x + side * 0.85 * span, 0.2, z + 0.84 + lift), 0.45 * span, 0.015, glow(theme["accent"]), (0, math.radians(side * -droop * 0.4), 0))
        shells += [inner, outer]
    sphere((x, 0.15, z + 1.0 + lift), (0.32, 0.4, 0.14), theme["core"](), 32)
    visor((x, -0.68, z + 0.85 + lift), 0.32, 0.1, theme["eyes"], (math.radians(-12), 0, 0))
    if p.get("tail", True):
        for step in range(4):
            sphere((x, 0.85 + step * 0.32, z + 0.78 + lift - step * 0.06), (0.1 - step * 0.018,) * 3, shell_mat if step < 3 else glow(theme["accent"], 10.0), 16)
    cylinder((x, 0.8, z + 0.92 + lift), 0.12, 0.2, real.gloss("Engine", (0.1, 0.11, 0.13), 0.3), (math.radians(90), 0, 0))
    sphere((x, 0.92, z + 0.92 + lift), (0.1, 0.04, 0.1), glow(theme["accent"], 12.0), 24)
    sphere((x, 0.1, z + 0.12), (0.7 * span, 0.55, 0.02), real.aura("Hover", theme["accent"], 3.0, 0.3), 32)
    return {"shells": shells, "top": (x, 0.05, z + 1.6 + lift), "center": (x, 0.1, z + 0.85 + lift), "radius": 1.2 * span, "width": 1.75 * span,
            "span": span, "lift": lift}


def drone(x, y, z, size, theme, shell_mat):
    body = sphere((x, y, z), (0.55 * size, 0.5 * size, 0.5 * size), shell_mat, 32)
    pill((x, y + 0.1 * size, z + 0.38 * size), (0.22 * size, 0.18 * size, 0.06 * size), theme["accent_shell"]())
    visor((x, y - 0.46 * size, z + 0.03 * size), 0.3 * size, 0.11 * size, theme["eyes"])
    for side in (-1, 1):
        sphere((x + side * 0.55 * size, y + 0.15 * size, z + 0.35 * size), (0.4 * size, 0.2 * size, 0.03 * size),
               real.iridescent("Wing", (0.8, 0.9, 1.0), transmission=0.85), 24, (0, math.radians(side * -20), 0))
    sphere((x, y, z - 0.5 * size), (0.15 * size, 0.15 * size, 0.06 * size), glow(theme["accent"], 10.0), 16)
    return body


SWARM_SPOTS = [(-1.05, 0.2, 1.75, 0.5), (1.0, 0.1, 0.55, 0.45), (1.1, 0.3, 1.7, 0.38), (-1.15, 0.0, 0.6, 0.4),
               (0.0, 0.5, 2.2, 0.32), (-0.55, -0.3, 2.1, 0.3), (0.6, -0.35, 2.15, 0.28)]


def swarm(x, z, theme, p=None):
    """A lead drone with its little ones. p: main (lead size), count (little drones)."""
    p = p or {}
    main_size = p.get("main", 1.25)
    shell_mat = theme["shell"]()
    lead_z = z + 0.2 + 0.65 * main_size
    main = drone(x, 0, lead_z, main_size, theme, shell_mat)
    small = []
    for index, (dx, dy, dz, size) in enumerate(SWARM_SPOTS[:p.get("count", 2)]):
        # Each little drone is a role of its own, so the game can fly it round the lead.
        with role(f"drone{index + 1}"):
            small.append(drone(x + dx * (0.6 + 0.35 * main_size), dy, z + dz * (0.55 + 0.35 * main_size), size, theme, shell_mat))
    info = {"shells": [main] + small, "top": (x, 0, lead_z + 0.65 * main_size), "center": (x, 0, lead_z), "radius": 0.8 * main_size, "width": 1.0 * main_size,
            "lead": (x, 0, lead_z), "lead_size": main_size, "drones": [(s.location.copy(), s.scale.x / 0.55) for s in small]}
    return info


def whale(x, z, theme, p=None):
    """A chubby whale-sub: a porthole visor, fins, a glowing thruster. p: size, fins (fin size)."""
    p = p or {}
    s = p.get("size", 1.0)
    fins = p.get("fins", 1.0)
    shell_mat = theme["shell"]()
    cz = z + 0.15 + 0.85 * s
    body = sphere((x, 0.15 * s, cz), (0.95 * s, 1.2 * s, 0.85 * s), shell_mat, 48)
    sphere((x, -0.15 * s, cz - 0.28 * s), (0.75 * s, 0.85 * s, 0.5 * s), theme["accent_shell"](), 48)
    torus((x, 0.15 * s, cz), 0.93 * s, 0.025, glow(theme["accent"]), (math.radians(90), 0, math.radians(90)))
    # A round porthole of a visor with the core glowing behind it.
    torus((x, -0.98 * s, cz + 0.12 * s), 0.36 * s, 0.06 * s, real.chrome("Rim", (0.7, 0.72, 0.76)), (math.radians(90), 0, 0))
    sphere((x, -0.95 * s, cz + 0.12 * s), (0.34 * s, 0.08 * s, 0.34 * s), real.gloss("Glass", (0.015, 0.02, 0.03), 0.04), 32)
    for side in (-1, 1):
        sphere((x + side * 0.13 * s, -1.03 * s, cz + 0.14 * s), (0.06 * s, 0.02, 0.1 * s), real.glow("EyeLight", theme["eyes"], 10.0), 16)
        pill((x + side * 0.95 * s, -0.05, cz - 0.4 * s), (0.32 * s * fins, 0.18 * s, 0.06), shell_mat, (0, math.radians(side * 25), 0))
        pill((x + side * 0.35 * s, 1.45 * s, cz + 0.55 * s), (0.3 * s * fins, 0.14 * s, 0.06), theme["accent_shell"](), (math.radians(30), math.radians(side * 20), 0))
    sphere((x, 0.35 * s, cz + 0.6 * s), (0.4 * s, 0.45 * s, 0.12 * s), theme["core"](), 32)
    cylinder((x, 1.35 * s, cz + 0.1 * s), 0.22 * s, 0.25, real.gloss("Engine", (0.1, 0.11, 0.13), 0.3), (math.radians(90), 0, 0))
    sphere((x, 1.5 * s, cz + 0.1 * s), (0.16 * s, 0.05, 0.16 * s), glow(theme["accent"], 12.0), 24)
    return {"shells": [body], "top": (x, 0.15 * s, cz + 1.1 * s), "center": (x, 0.15 * s, cz), "radius": 1.2 * s, "width": 1.5 * s, "size": s}


FAMILIES = {"slime": slime, "crab": crab, "worm": worm, "ray": ray, "swarm": swarm, "whale": whale}


# --- Growth -------------------------------------------------------------------------------------
#
# Two axes make a pet grow, so a child feels it:
#   tier - the pet gets bigger and gains an outfit piece per tier: a beacon antenna, then a
#          thruster pack and shoulder armour, then energy wings and an orbit ring, then gold
#          armour with a crown and an aura;
#   zone - a harder zone adds a richer flair that also grows with the tier: hull bits in the
#          Debris Belt, crystal shards in the Ice Rings, a flame crest in the Red Nebula, an
#          accretion disc with little planets at the Event Horizon.

GROWTH = [0.74, 0.86, 1.0, 1.14, 1.3]


def cone(location, radius, depth, mat, direction=(0, 0, 1)):
    """A spike pointing along `direction` from its base at `location`."""
    d = Vector(direction).normalized()
    centre = Vector(location) + d * depth / 2
    bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=0, depth=depth, location=tuple(centre), vertices=24)
    obj = bpy.context.active_object
    obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return _tag(real.assign(_smooth(obj, 0), mat))


@in_role("ring")
def tier_ring(x, z, width, tier):
    torus((x, 0, z + 0.03), width, 0.045 + 0.01 * tier, real.glow("TierRing", TIER_COLORS[tier], 1.5 + tier * 1.5))


@in_role("fx")
def motes(info, color, count, strength=10.0, spread=0.55, size=0.04):
    cx, cy, cz = info["center"]
    radius = info["radius"] + spread
    mat = real.glow("Mote", color, strength)
    for index in range(count):
        angle = index / count * math.tau + 0.3
        s = size * (0.7 + 0.6 * ((index * 7) % 5) / 4)
        sphere((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius * 0.55, cz + 0.15 + 0.8 * math.sin(index * 1.7)), (s, s, s), mat, 10)


def _flank(info):
    """Where hull parts on the sides and back sit: a centre, a half-width and a snap that puts a
    point on the hull. A worm's are on its head: its body centre sits back towards the curled tail,
    so parts placed from it sank into the head on one side and floated in the air on the other.
    Other pets keep their body centre and place parts as they are."""
    if "head" not in info:
        return info["center"], info["radius"], lambda point, lift=0.0: point
    head = Vector(info["head"])
    r = info["head_r"]

    def snap(point, lift=0.0):
        return tuple(head + (Vector(point) - head).normalized() * (r + lift))

    return (head.x, head.y, head.z - 0.1), r * 1.2, snap


def details(info, theme):
    """Small hull detail every pet has: side lights, a vent grille, a bolt."""
    (cx, cy, cz), r, snap = _flank(info)
    r *= 0.82
    dark = real.gloss("Vent", (0.06, 0.065, 0.075), 0.3)
    bolt = real.chrome("Bolt", (0.75, 0.77, 0.8), 0.2)
    for side in (-1, 1):
        sx = cx + side * r
        for step in range(3):
            sphere(snap((sx + side * 0.02, cy - 0.1 + step * 0.13, cz + 0.12)), (0.03, 0.035, 0.035), glow(theme["accent"] if step else theme["eyes"], 9.0), 10)
        for step in range(3):
            pill(snap((sx - side * 0.05, cy + 0.35, cz - 0.12 + step * 0.08), 0.01), (0.03, 0.14, 0.018), dark, (0, 0, 0), 0.5)
        sphere(snap((sx - side * 0.04, cy + 0.12, cz - 0.28)), (0.035, 0.035, 0.035), bolt, 12)
        # An emblem in the trim colour with a glowing rim: the guardian's badge on the flank.
        emblem = snap((sx + side * 0.03, cy - 0.32, cz - 0.05), 0.03)
        cylinder(emblem, 0.13, 0.03, theme["accent_shell"](), (0, math.radians(90), 0), 24)
        torus(emblem, 0.13, 0.015, glow(theme["accent"], 6.0), (0, math.radians(90), 0))


def beacon(info, color, strength):
    """Tiers 1-3: an antenna with a light in the tier colour."""
    tx, ty, tz = info["top"]
    cylinder((tx + 0.18, ty + 0.12, tz - 0.05), 0.022, 0.42, real.chrome("Mast", (0.75, 0.77, 0.8)), (0, math.radians(12), 0))
    sphere((tx + 0.23, ty + 0.12, tz + 0.18), (0.075, 0.075, 0.075), real.glow("Beacon", color, strength), 16)


def pack(info, color, armour):
    """Tier 2+: a twin thruster pack on the back and armour plates on the shoulders."""
    (cx, cy, cz), r, snap = _flank(info)
    engine = real.gloss("Engine", (0.1, 0.11, 0.13), 0.3)
    for side in (-1, 1):
        ex = cx + side * 0.32
        # The engine's middle on the back of the hull (a worm's: the back of its head).
        ex, ey, ez = snap((ex, cy + r * 0.85, cz + 0.2), 0.05)
        cylinder((ex, ey, ez), 0.13, 0.4, engine, (math.radians(90), 0, 0))
        torus((ex, ey + 0.2, ez), 0.12, 0.025, glow(color, 8.0), (math.radians(90), 0, 0))
        sphere((ex, ey + 0.24, ez), (0.1, 0.04, 0.1), glow(color, 14.0), 16)
        info["shells"].append(pill(snap((cx + side * r * 0.78, cy + 0.05, cz + r * 0.45), 0.03), (0.22, 0.3, 0.07), armour, (0, math.radians(side * -40), 0)))


# A fairy wing, traced from the user's reference (2026-11-08) in its image pixels: x right, y down,
# the root at WING_ROOT. A narrow upper lobe, a big forewing with a sharp tip swept up and out, and
# two hind lobes with tails.
WING_ROOT = (15, 745)
# Key points only (low poly); the wing softens them a little when it is built.
WING_TRACE = [(15, 745), (45, 520), (140, 280), (228, 215), (240, 330), (222, 430), (350, 220), (560, 50), (690, 15), (590, 150),
              (525, 400), (500, 640), (330, 760), (460, 860), (490, 950), (400, 975), (320, 930), (290, 1080), (140, 1190),
              (110, 1050), (30, 830)]
# Veins from the root out into each lobe, as in the reference.
WING_VEIN_TRACES = [
    [(15, 745), (120, 420), (205, 235)],
    [(15, 745), (80, 500), (135, 320)],
    [(15, 745), (250, 520), (420, 300), (610, 80)],
    [(15, 745), (280, 600), (450, 420), (525, 330)],
    [(15, 745), (260, 660), (420, 620), (505, 570)],
    [(15, 745), (250, 800), (400, 880), (475, 945)],
    [(15, 745), (180, 880), (250, 1020), (200, 1140)],
    [(15, 745), (110, 860), (145, 1060)],
]
# Where fairy dust flies off with each stroke: part of the outer edge, a little inside it (the forewing
# from its tip down, then the hind lobe's rim).
WING_DUST_TRACE = [(670, 30), (600, 150), (545, 280), (520, 420), (505, 560), (455, 865), (475, 935), (420, 965)]
# Nested contours inside the edge (the reference's cells), as fractions of the outline towards the root.
WING_CELLS = [0.8, 0.6]


def _from_trace(points):
    """Reference pixels to wing units: the root at (0, 0), y up; the forewing reaches about 1 out."""
    rx, ry = WING_ROOT
    return [((x - rx) / 680.0, (ry - y) / 680.0) for x, y in points]


WING_OUTLINE = _from_trace(WING_TRACE)
WING_VEINS = [_from_trace(vein) for vein in WING_VEIN_TRACES]


def _smoothed(points, closed, rounds):
    """Chaikin corner cutting: the low-poly edges soften into curves, a little per round."""
    for _ in range(rounds):
        out = [] if closed else [points[0]]
        count = len(points) if closed else len(points) - 1
        for index in range(count):
            (x0, y0), (x1, y1) = points[index], points[(index + 1) % len(points)]
            out += [(0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1), (0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1)]
        points = out if closed else out + [points[-1]]
    return points


def _scaled_towards(points, factor, centre=None):
    """The outline shrunk towards `centre` (its own centre by default): a contour inside it."""
    cx, cy = centre or (sum(x for x, _ in points) / len(points), sum(y for _, y in points) / len(points))
    return [(cx + (x - cx) * factor, cy + (y - cy) * factor) for x, y in points]


def _wing_mesh(points, hinge, side, tilt, size, mat):
    """A flat wing polygon at `hinge`, mirrored by `side`, swept back by `tilt` degrees."""
    import bmesh

    mesh = bpy.data.meshes.new("Wing")
    bm = bmesh.new()
    verts = [bm.verts.new((side * x * size, 0.0, y * size)) for x, y in points]
    bm.faces.new(verts if side > 0 else list(reversed(verts)))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Wing", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = hinge
    obj.rotation_euler = (math.radians(-10), 0, math.radians(side * -tilt))
    solid = obj.modifiers.new("Thickness", "SOLIDIFY")
    solid.thickness = 0.03
    solid.offset = 0
    return _tag(real.assign(obj, mat))


def _wing_line(points, hinge, side, tilt, size, mat, radius):
    """A glowing tube along `points` in the wing's plane: its edge or a vein."""
    curve = bpy.data.curves.new("WingLine", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, (x, y) in zip(spline.points, points):
        point.co = (side * x * size, 0.0, y * size, 1.0)
    obj = bpy.data.objects.new("WingLine", curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = hinge
    obj.rotation_euler = (math.radians(-10), 0, math.radians(side * -tilt))
    obj.data.materials.append(mat)
    return _tag(obj)


def wings(info, color, size, gold=False):
    """Tier 3+: a pair of fairy wings behind the pet: a see-through membrane in the tier colour
    with a glowing edge and veins. Each side is its own role (wingL, wingR) and is hinged at its
    root, so the game can flap it."""
    # Hinged behind the head of a worm (symmetric), behind the body of anything else; the span still
    # follows the whole pet.
    (cx, cy, cz), _, _ = _flank(info)
    if "head" in info:
        cz += 0.1
    r = info["radius"]
    membrane = real.iridescent("GoldWing", GOLD, transmission=0.5, glow=1.5) if gold else real.iridescent("EnergyWing", color, transmission=0.6, glow=1.5)
    edge = glow(GOLD if gold else color, 10.0)
    span = (0.8 + 0.25 * r) * size * 2.0
    for side in (-1, 1):
        hinge = (cx + side * r * 0.35, cy + r * 0.5, cz + 0.35)
        # Softened: two rounds of corner cutting keep the lobes and the sharp tip but round the edges.
        outline = _smoothed(WING_OUTLINE, True, 2)
        name = "wingL" if side < 0 else "wingR"
        with role(name):
            _wing_mesh(outline, hinge, side, 22, span, membrane)
            _wing_line(outline + [outline[0]], hinge, side, 22, span, edge, 0.017)
            for vein in WING_VEINS:
                _wing_line(_smoothed(vein, False, 2), hinge, side, 22, span, edge, 0.008)
            # The cells: contours nested inside the edge, drawn towards the root.
            for factor in WING_CELLS:
                cell = _scaled_towards(outline, factor, (0.0, 0.0))
                _wing_line(cell + [cell[0]], hinge, side, 22, span, edge, 0.006)
        # The hinge marker: the exact root, so the game turns the wing about it (the root stays put,
        # the edge sweeps the most). Invisible in game.
        with role("hinge" + name[-1]):
            sphere(hinge, (0.03, 0.03, 0.03), edge, 8)
        # Dust markers along part of the outer edge (the forewing from its tip down, the hind lobe):
        # in game, fairy dust flies off them with each stroke. Each is a role of its own so it stays
        # a separate point; the game turns them into emitters and drops the markers.
        turn = Euler((math.radians(-10), 0, math.radians(side * -22))).to_matrix()
        for index, (x, y) in enumerate(_from_trace(WING_DUST_TRACE)):
            point = Vector(hinge) + turn @ Vector((side * x * span, 0.0, y * span))
            with role(f"dust{name[-1]}{index + 1}"):
                sphere(tuple(point), (0.02, 0.02, 0.02), edge, 6)


@in_role("fx")  # In game, orbiting comets with trails take the rings' place.
def orbit(info, color, tilt, extra=0.45, thickness=0.02):
    cx, cy, cz = info["center"]
    torus((cx, cy, cz), info["radius"] + extra, thickness, real.glow("Orbit", color, 8.0), (math.radians(tilt), math.radians(-tilt * 0.6), 0))


def crown(info):
    """Tier 4: a gold crown of gem-tipped spikes instead of the antenna."""
    tx, ty, tz = info["top"]
    if "head" in info:
        # On a worm's head, not hovering over its feelers.
        tz = info["head"][2] + info["head_r"] + 0.03
    gold = real.chrome("Crown", GOLD, 0.2)
    torus((tx, ty, tz - 0.05), 0.32, 0.06, gold)
    for index in range(5):
        angle = index / 5 * math.tau - math.pi / 2
        out = Vector((math.cos(angle) * 0.25, math.sin(angle) * 0.25, 1)).normalized()
        base = Vector((tx + math.cos(angle) * 0.3, ty + math.sin(angle) * 0.3, tz - 0.02))
        height = 0.42 if index == 0 else 0.3
        cone(tuple(base), 0.08, height, gold, tuple(out))
        gem = (1.0, 0.3, 0.5) if index == 0 else (0.4, 0.9, 1.0)
        sphere(tuple(base + out * height), (0.055, 0.055, 0.055), real.glow("Gem", gem, 12.0), 12)


@in_role("rays")
def sunburst(info, long_colour=(1.0, 0.78, 0.3), short_colour=(1.0, 0.92, 0.6)):
    """Tier 4: rays fanning out behind the pet, like a medal (golden, or fire on a meteor)."""
    cx, cy, cz = info["center"]
    inner = info["radius"] * 0.6
    back = cy + info["radius"] * 0.9
    long_ray = real.glow("Ray", long_colour, 3.0)
    short_ray = real.glow("RayShort", short_colour, 4.0)
    for index in range(16):
        angle = index / 16 * math.tau
        out = Vector((math.cos(angle), 0, math.sin(angle)))
        length = 1.0 if index % 2 == 0 else 0.6
        base = Vector((cx, back, cz)) + out * inner
        spike = cone(tuple(base), 0.09, length, long_ray if index % 2 == 0 else short_ray, tuple(out))
        spike.scale = (1.0, 0.25, 1.0)


FIRE = (1.0, 0.42, 0.08)


def meteor_fire(info, tier):
    """A meteor pet burns: a comet tail behind, flame tongues over its back, burning rocks circling
    it and embers. Each grows with the tier, like the outfit."""
    cx, cy, cz = info["center"]
    r = info["radius"]
    with role("fx"):
        _comet(cx, cy, cz, r, tier)
    # Burning rocks circling, each with its own little tail.
    rock = real.molten("MeteorRock")
    # In game, fireball comets with flame tails take the rocks' place.
    with role("fx"):
        for index in range(2 + tier):
            angle = index / (2 + tier) * math.tau + 0.7
            where = Vector((cx + math.cos(angle) * (r + 0.55), cy + math.sin(angle) * (r + 0.2), cz + 0.35 + 0.35 * math.sin(index * 2.3)))
            size = 0.13 + 0.03 * (index % 2)
            gem(tuple(where), (size, size * 0.85, size * 0.9), rock, (index, index * 0.7, 0))
            heading = Vector((-math.sin(angle), math.cos(angle), 0)).normalized()
            cone(tuple(where - heading * size * 0.4), size * 0.8, 0.45, real.glow("RockTail", FIRE, 3.5), tuple(-heading))
    motes(info, (1.0, 0.5, 0.1), 14 + tier * 4, 12.0, 0.5, 0.05)


def _comet(cx, cy, cz, r, tier):
    """A meteor's comet tail and the flame tongues over its back."""
    # The comet tail: tapered flames streaming back, longest in the middle.
    count = 5 + tier
    for index in range(count):
        t = (index - (count - 1) / 2) / max(count - 1, 1)
        length = (1.3 + 0.35 * tier) * (1.0 - abs(t) * 0.55)
        colour = (1.0, 0.3 + 0.35 * (1 - abs(t)), 0.06)
        base = (cx + t * r * 1.1, cy + r * 0.75, cz + 0.15 + 0.25 * math.cos(t * 3))
        cone(base, 0.16 + 0.02 * tier, length, real.glow("Tail", colour, 3.5), (t * 0.5, 1, 0.3))
        cone(base, 0.08, length * 0.6, real.glow("TailCore", (1.0, 0.85, 0.4), 5.0), (t * 0.5, 1, 0.3))
    # Flame tongues licking up off the back.
    for index in range(3 + tier):
        angle = math.pi * (0.15 + 0.7 * index / max(2 + tier, 1))
        base = (cx + math.cos(angle) * r * 0.7, cy + 0.2, cz + math.sin(angle) * r * 0.55)
        cone(base, 0.1, 0.35 + 0.08 * tier, real.glow("Tongue", (1.0, 0.55, 0.12), 4.0), (math.cos(angle) * 0.6, 0.4, 1))


# --- Zone flair: the harder the zone, the richer ------------------------------------------------


def _back_arc(info, count, spread=1.0):
    """Points along the pet's top-back, each with an outward direction."""
    tx, ty, tz = info["top"]
    cx = _flank(info)[0][0]
    for index in range(count):
        t = ((index - (count - 1) / 2) / (count - 1) * spread) if count > 1 else 0.0
        base = Vector((cx + t * info["radius"] * 0.9, ty + 0.35, tz - 0.45 - abs(t) * 0.35))
        out = Vector((t * 0.9, 0.45, 1.0)).normalized()
        yield t, base, out


def flair_debris(info, theme, tier):
    """Debris Belt: plain hull bits, a striped hazard plate."""
    tx, ty, tz = info["top"]
    stripe = real.gloss("Hazard", (0.08, 0.08, 0.09), 0.25)
    for step in range(min(tier, 3)):
        pill((tx - 0.25 + step * 0.25, ty + 0.4, tz - 0.42), (0.09, 0.05, 0.03), stripe if step % 2 else theme["accent_shell"]())


def flair_ice(info, theme, tier):
    """Ice Rings: crystal shards on the back, more and bigger with each tier."""
    crystal = real.crystal("Shard", (0.7, 0.92, 1.0), 1.2 + tier * 0.6)
    for t, base, out in _back_arc(info, 2 + tier * 2, 1.3):
        height = (0.35 + 0.12 * tier) * (1.0 - abs(t) * 0.45)
        cone(tuple(base), 0.09 + 0.015 * tier, height, crystal, tuple(out))
    if tier >= 2:
        motes(info, (0.6, 0.95, 1.0), 4 + tier * 3, 8.0, 0.4, 0.035)


PLANETS = [(0.95, 0.55, 0.3), (0.4, 0.8, 1.0), (0.85, 0.4, 1.0), (1.0, 0.85, 0.45), (0.5, 1.0, 0.7)]


@in_role("fx")
def twinkle(location, size, colour, strength=12.0):
    """A four-pointed sparkle facing the viewer."""
    mat = real.glow("Twinkle", colour, strength)
    x, y, z = location
    for direction, length in (((1, 0, 0), 1.0), ((-1, 0, 0), 1.0), ((0, 0, 1), 1.4), ((0, 0, -1), 1.4)):
        spike = cone(location, size * 0.28, size * length, mat, direction)
        spike.scale = (spike.scale.x, spike.scale.y * 0.3, spike.scale.z) if direction[2] == 0 else (spike.scale.x * 0.3, spike.scale.y, spike.scale.z)
    sphere(location, (size * 0.22,) * 3, mat, 12)


@in_role("fx")
def flair_nebula(info, theme, tier):
    """Red Nebula: embers and sparks rising off the pet like heat, more with each tier."""
    cx, cy, cz = info["center"]
    r = info["radius"]
    warm = [(1.0, 0.35, 0.12), (1.0, 0.55, 0.15), (1.0, 0.25, 0.4)]
    count = 8 + tier * 5
    for index in range(count):
        t = index / count
        angle = index * 2.39996
        lift = t * (1.4 + 0.25 * tier)
        spread = r * (0.55 + 0.45 * (1 - t))
        size = 0.05 * (1.2 - 0.7 * t)
        sphere((cx + math.cos(angle) * spread, cy + math.sin(angle) * spread * 0.6, cz + 0.1 + lift), (size,) * 3, real.glow("Ember", warm[index % 3], 9.0), 10)
    for index in range(1 + tier // 2):
        angle = 0.8 + index * 2.1
        twinkle((cx + math.cos(angle) * r * 0.9, cy - 0.3, cz + 0.6 + 0.35 * index), 0.18, (1.0, 0.7, 0.4))


@in_role("fx")
def flair_horizon(info, theme, tier):
    """Event Horizon: a little spiral galaxy of stars turning round the pet, with twinkles."""
    cx, cy, cz = info["center"]
    r = info["radius"]
    colours = [(1.0, 1.0, 1.0), (0.8, 0.65, 1.0), (0.6, 0.8, 1.0), (1.0, 0.75, 0.95)]
    per_arm = 10 + tier * 4
    for arm in range(2):
        for index in range(per_arm):
            t = index / per_arm
            angle = arm * math.pi + t * math.tau * 1.1
            radius = r * (0.75 + 0.75 * t)
            size = 0.055 * (1.0 - 0.6 * t)
            where = (cx + math.cos(angle) * radius, cy + math.sin(angle) * radius * 0.7, cz - 0.15 + 0.55 * math.sin(angle) * (0.3 + t * 0.4))
            sphere(where, (size,) * 3, real.glow("StarDust", colours[(index + arm) % 4], 12.0), 10)
    for index in range(2 + tier):
        angle = 0.5 + index * 2.4
        reach = r * (1.0 + 0.25 * (index % 2))
        twinkle((cx + math.cos(angle) * reach, cy - 0.4, cz + 0.2 + 0.5 * math.sin(index * 1.7)), 0.16 + 0.03 * (index % 3), colours[index % 4], 14.0)
    if tier >= 2:
        with role("orbit"):
            for index in range(tier - 1):
                angle = 2.0 + index * 2.6
                colour = PLANETS[index % len(PLANETS)]
                sphere((cx + math.cos(angle) * r * 1.35, cy + math.sin(angle) * r * 0.8, cz + 0.45), (0.1,) * 3, real.gloss("Planet", colour, 0.3), 16)


FLAIR = {"debris": flair_debris, "ice": flair_ice, "nebula": flair_nebula, "horizon": flair_horizon}


# --- Building -----------------------------------------------------------------------------------


def _grow(objects, x, z, factor):
    bpy.context.view_layer.update()
    pivot = Matrix.Translation(Vector((x, 0, z)))
    scale = pivot @ Matrix.Diagonal(Vector((factor, factor, factor, 1.0))) @ pivot.inverted()
    for obj in objects:
        if obj.parent is None:
            obj.matrix_world = scale @ obj.matrix_world


def build(family, zone, tier, x, z, meteor=False, look=None, shape=None, signature=()):
    """One pet at base point (x, 0, z): the family's shell in the zone's finish, grown to `tier`.
    A kind passes its colours (`look`), its silhouette (`shape`, the family's parameters) and its
    `signature` parts. A meteor pet has a molten shell and burns, whatever its tier."""
    paint = theme(zone, look)
    before = set(bpy.data.objects)
    info = FAMILIES[family](x, z, paint, shape)

    for part in signature:
        part(info, paint)
    # A meteor pet keeps its tier's whole outfit and burns on top of it: the outfit's light turns to
    # fire, so a meteor legendary is the richest pet of all (it also earns the most).
    color = FIRE if meteor else TIER_COLORS[tier]
    details(info, paint)
    FLAIR[zone](info, paint, tier)
    if 1 <= tier < 4:
        beacon(info, color, 6.0 + tier * 3)
    if tier >= 2:
        pack(info, color, real.chrome("GoldArmour", GOLD, 0.22) if tier == 4 else paint["accent_shell"]())
    if tier >= 3:
        wings(info, color, 0.85 if tier == 3 else 1.0, gold=tier == 4 and not meteor)
        orbit(info, color, 18)
        motes(info, color, 8 if tier == 3 else 16, 12.0)
    if tier == 4:
        gold = real.chrome("Gold", GOLD, 0.24)
        for shell in info["shells"]:
            real.assign(shell, gold)
        crown(info)
        orbit(info, FIRE if meteor else GOLD, -24, 0.75, 0.03)
        sunburst(info, *((FIRE, (1.0, 0.75, 0.3)) if meteor else ((1.0, 0.78, 0.3), (1.0, 0.92, 0.6))))
    if meteor:
        molten = real.molten("Meteor")
        for shell in info["shells"]:
            real.assign(shell, molten)
        meteor_fire(info, tier)
    _grow(set(bpy.data.objects) - before, x, z, GROWTH[tier])
    tier_ring(x, z, info["width"] * GROWTH[tier], tier)
    return info
