# The twelve jetpacks (docs/plans/POLISH.md, "Джетпаки"): one per grade, Starter to Infinity
# (UpgradeConfig.JETPACK_NAME_KEYS). A better jetpack wears more: twin tanks → a central engine
# → wings → a legendary piece (an orb, a disc, a ring). Built on the back of an R15 UpperTorso
# (2 × 1.6 × 1 studs; Blender units are studs) whose back face is at +Y (the back, section 1 of
# docs/design/BLENDER_ROBLOX.md).
#
# Every part carries a role (`obj["role"]`), the contract with the game: `body`, `trim`, `metal`,
# `glow` and `glass` are paints the game may recolour, `nozzle` empties mark where a flame leaves
# (their −Z points down the jet).

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))

import bpy  # noqa: E402
import real  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

BACK = 0.5  # the torso's back face, Y

# Game detail (export) or render detail (concept sheets). A jetpack rides on every character, so
# the game's meshes are kept light: a few hundred triangles a piece, about 2-4k a jetpack.
LOW_POLY = False


def _segments(full, low):
    return low if LOW_POLY else full

# Each grade: its colours (body, trim, glow — the flame's hue, metal of the nozzles) and what it wears.
# `form`: tanks (twin tanks), engine (a central engine between pods), shell (one smooth hull).
GRADES = [
    # 0 Starter: plain steel tanks, simple cone nozzles, one blue band.
    {"name": "Стартовый", "body": (0.62, 0.65, 0.70), "trim": (0.16, 0.17, 0.21), "glow": (0.25, 0.7, 1.0),
     "metal": (0.30, 0.31, 0.34), "form": "tanks", "nozzle": "cone", "bands": 1},
    # 1 Spark: cream tanks with orange bands, bell nozzles, little tail fins.
    {"name": "Искра", "body": (0.86, 0.80, 0.66), "trim": (1.0, 0.45, 0.08), "glow": (1.0, 0.55, 0.12),
     "metal": (0.34, 0.33, 0.32), "form": "tanks", "nozzle": "bell", "bands": 2, "fins": "small"},
    # 2 Comet: blue, a nose cone over both tanks, swept fins, a glowing seam.
    {"name": "Комета", "body": (0.20, 0.42, 0.85), "trim": (0.85, 0.92, 1.0), "glow": (0.35, 0.75, 1.0),
     "metal": (0.55, 0.58, 0.64), "form": "tanks", "nozzle": "bell", "bands": 2, "fins": "swept", "fairing": True,
     "seam": True},
    # 3 Plasma: violet, a glass tube of plasma between the tanks, coils round the nozzles.
    {"name": "Плазма", "body": (0.42, 0.22, 0.70), "trim": (0.12, 0.08, 0.18), "glow": (0.85, 0.35, 1.0),
     "metal": (0.55, 0.52, 0.62), "form": "engine", "nozzle": "bell", "core": "tube", "coils": 1, "seam": True},
    # 4 Ion: teal engine pods ringed with glowing coils, a spine down the middle.
    {"name": "Ион", "body": (0.05, 0.55, 0.52), "trim": (0.85, 0.95, 0.93), "glow": (0.1, 1.0, 0.85),
     "metal": (0.62, 0.66, 0.68), "form": "engine", "nozzle": "ion", "core": "spine", "coils": 3, "seam": True},
    # 5 Pulsar: one smooth white ceramic hull, blue lights, short wings.
    {"name": "Пульсар", "body": (0.92, 0.93, 0.96), "trim": (0.18, 0.32, 0.70), "glow": (0.45, 0.65, 1.0),
     "metal": (0.70, 0.73, 0.80), "form": "shell", "hull": "round", "nozzle": "bell", "wings": "short", "coils": 1, "seam": True,
     "lights": True},
    # 6 Quasar: red hull, gold trim and wings, bigger engines.
    {"name": "Квазар", "body": (0.80, 0.16, 0.08), "trim": (1.0, 0.72, 0.22), "glow": (1.0, 0.5, 0.1),
     "metal": (1.0, 0.72, 0.22), "form": "shell", "hull": "fin", "nozzle": "big", "wings": "swept", "gold_trim": True,
     "coils": 1, "seam": True, "lights": True},
    # 7 Antimatter: black hull, magenta seams, a caged orb of antimatter.
    {"name": "Антиматерия", "body": (0.035, 0.03, 0.05), "trim": (0.30, 0.10, 0.35), "glow": (1.0, 0.12, 0.6),
     "metal": (0.25, 0.22, 0.30), "form": "shell", "nozzle": "big", "wings": "swept", "core": "orb", "coils": 2,
     "seam": True, "lights": True},
    # 8 Singularity: graphite hull, a black sphere in a blue disc.
    {"name": "Сингулярность", "body": (0.13, 0.14, 0.18), "trim": (0.05, 0.05, 0.07), "glow": (0.2, 0.35, 1.0),
     "metal": (0.40, 0.42, 0.50), "form": "shell", "nozzle": "big", "wings": "blade", "core": "hole", "coils": 2,
     "seam": True},
    # 9 Hyperdrive: white and cyan, long blade wings, four nozzles.
    {"name": "Гиперпривод", "body": (0.85, 0.92, 0.96), "trim": (0.05, 0.25, 0.35), "glow": (0.0, 0.95, 1.0),
     "metal": (0.75, 0.80, 0.85), "form": "shell", "hull": "slim", "nozzle": "quad", "wings": "long", "coils": 2, "seam": True,
     "lights": True},
    # 10 Wormhole: deep violet, a green portal ring behind the back.
    {"name": "Червоточина", "body": (0.16, 0.07, 0.24), "trim": (0.45, 1.0, 0.55), "glow": (0.35, 1.0, 0.5),
     "metal": (0.35, 0.30, 0.42), "form": "shell", "nozzle": "quad", "wings": "blade", "core": "portal", "coils": 2,
     "seam": True},
    # 11 Infinity: white and gold, gold wings, an infinity loop for a halo, four nozzles.
    {"name": "Бесконечность", "body": (0.96, 0.93, 0.86), "trim": (1.0, 0.75, 0.25), "glow": (1.0, 0.82, 0.35),
     "metal": (1.0, 0.75, 0.25), "form": "shell", "hull": "fin", "nozzle": "quad", "wings": "long", "gold_trim": True,
     "core": "infinity", "coils": 3, "seam": True, "lights": True},
]


# --- Materials ----------------------------------------------------------------------------------


def _materials(grade):
    g = GRADES[grade]
    body = real.chrome("Body", g["body"], 0.32) if g["form"] == "tanks" else real.gloss("Body", g["body"], 0.18)
    if g["form"] == "tanks" and grade > 0:
        # Painted tanks: lacquer over metal.
        body = real.gloss("Body", g["body"], 0.22, 0.4)
    gold = real.chrome("Gold", (1.0, 0.72, 0.25), 0.18)
    return {
        "body": body,
        "trim": gold if g.get("gold_trim") else real.gloss("Trim", g["trim"], 0.25),
        "metal": real.chrome("Metal", g["metal"], 0.28),
        "dark": real.gloss("Dark", (0.035, 0.037, 0.045), 0.35),
        "glow": real.glow("Glow", g["glow"], 3.0),
        "hot": real.glow("Hot", tuple(0.55 + 0.45 * c for c in g["glow"]), 4.0),
        "glass": _glass(g["glow"]),
        "gold": gold,
    }


def _glass(color):
    mat, nodes, links, bsdf = real._principled("Glass")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.04
    bsdf.inputs["Alpha"].default_value = 0.35
    bsdf.inputs["Coat Weight"].default_value = 1.0
    if hasattr(mat, "use_raytrace_refraction"):
        mat.use_raytrace_refraction = False
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    return mat


# --- Parts --------------------------------------------------------------------------------------


def _tag(obj, role, mat):
    obj["role"] = role
    real.assign(obj, mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def _bevel(obj, width, segments=3):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = _segments(segments, 1)
    mod.limit_method = "ANGLE"
    return obj


def capsule(location, radius, height, role, mat, rotation=(0, 0, 0)):
    """A tank: a cylinder with round ends, `height` end to end, standing along Z."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=_segments(40, 16), ring_count=_segments(20, 8), radius=radius, location=location, rotation=rotation)
    obj = bpy.context.active_object
    # Stretch the middle: move the upper half up, the lower half down.
    half = max(0.0, height / 2 - radius)
    for vertex in obj.data.vertices:
        vertex.co.z += half if vertex.co.z > 0 else -half if vertex.co.z < 0 else 0
    return _tag(obj, role, mat)


def cylinder(location, radius, depth, role, mat, rotation=(0, 0, 0), radius2=None, vertices=40, bevel=0.03):
    vertices = _segments(vertices, 14)
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=radius2, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    if bevel:
        _bevel(obj, bevel)
    return _tag(obj, role, mat)


def torus(location, major, minor, role, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=location, major_radius=major, minor_radius=minor, rotation=rotation, major_segments=_segments(64, 12 if major < 0.25 else 24), minor_segments=_segments(16, 4))
    return _tag(bpy.context.active_object, role, mat)


def sphere(location, radius, role, mat, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=_segments(40, 14), ring_count=_segments(20, 7), radius=radius, location=location)
    obj = bpy.context.active_object
    obj.scale = scale
    return _tag(obj, role, mat)


def pill(location, size, role, mat, rotation=(0, 0, 0), roundness=0.7):
    """A rounded box: `size` is the half extents."""
    bpy.ops.mesh.primitive_cube_add(location=location, scale=size, rotation=rotation)
    obj = bpy.context.active_object
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = min(size) * roundness
    mod.segments = _segments(6, 2)
    mod.limit_method = "NONE"
    return _tag(obj, role, mat)


def wing(side, root, span, chord, sweep, droop, role, mat, thickness=0.06):
    """A flat tapered wing from `root` outwards along `side`·X, swept back-down."""
    tip_chord = chord * 0.45
    pts = [
        (0, 0, chord / 2),
        (0, 0, -chord / 2),
        (span, sweep, -droop - tip_chord / 2),
        (span, sweep, -droop + tip_chord / 2),
    ]
    mesh = bpy.data.meshes.new("Wing")
    verts = []
    for y_off in (-thickness / 2, thickness / 2):
        for x, y, z in pts:
            verts.append((root[0] + side * x, root[1] + y + y_off, root[2] + z))
    faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new("Wing", mesh)
    bpy.context.scene.collection.objects.link(obj)
    _bevel(obj, thickness * 0.45, 2)
    return _tag(obj, role, mat)


def nozzle_marker(location):
    obj = bpy.data.objects.new("Nozzle", None)
    obj.location = location
    obj.empty_display_type = "SINGLE_ARROW"
    obj.rotation_euler = (math.pi, 0, 0)  # −Z down... the arrow (+Z) flipped to point down
    obj["role"] = "nozzle"
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- Pieces -------------------------------------------------------------------------------------


def _straps(m):
    """Straps over the shoulders: for the renders only — in game they would sink into the torso
    (and the avatar's clothes) and only cost triangles."""
    if LOW_POLY:
        return
    for side in (-1, 1):
        pill((side * 0.55, BACK - 0.5, 0.72), (0.09, 0.55, 0.04), "trim", m["dark"])


def _nozzle(x, y, top, g, m, size=1.0):
    """One engine nozzle hanging from `top` (Z) at (x, y): a collar, the bell, a hot throat."""
    kind = g["nozzle"]
    r = 0.17 * size
    cylinder((x, y, top - 0.05), r * 1.05, 0.12, "metal", m["metal"])
    if kind == "cone":
        length = 0.28 * size
        cylinder((x, y, top - 0.1 - length / 2), r * 1.1, length, "metal", m["metal"], radius2=r * 0.8)
        bottom = top - 0.1 - length
        exit_r = r * 1.1
    else:
        length = (0.36 if kind == "bell" else 0.44 if kind in ("big", "quad") else 0.4) * size
        flare = 1.45 if kind != "ion" else 1.15
        cylinder((x, y, top - 0.1 - length / 2), r * flare, length, "metal", m["metal"], radius2=r * 0.7)
        bottom = top - 0.1 - length
        exit_r = r * flare
        if kind == "ion" or g.get("coils", 0) >= 1:
            for i in range(max(1, min(g.get("coils", 1), 1 if kind == "quad" and LOW_POLY else 3))):
                torus((x, y, top - 0.16 - i * 0.1 * size), r * (0.95 + 0.12 * i), 0.025 * size, "glow", m["glow"])
        if kind in ("big", "quad"):
            # A dark lip at the exit.
            torus((x, y, bottom + 0.01), exit_r * 0.98, 0.03 * size, "trim", m["dark"])
    # The hot throat inside the exit (seen from below and from the side through the bell's mouth).
    cylinder((x, y, bottom + 0.06), exit_r * 0.8, 0.02, "glow", m["hot"], bevel=0)
    nozzle_marker((x, y, bottom))


def _tanks(g, m):
    """Twin tanks on a back plate."""
    y = BACK + 0.12 + 0.3
    pill((0, BACK + 0.06, 0.0), (0.62, 0.06, 0.62), "trim", m["dark"])
    for side in (-1, 1):
        x = side * 0.42
        capsule((x, y, 0.05), 0.3, 1.45, "body", m["body"])
        for i in range(g.get("bands", 0)):
            z = 0.32 - i * 0.22
            cylinder((x, y, z), 0.315, 0.08, "trim", m["trim"], bevel=0.015)
        if g.get("seam"):
            # A glowing seam down the outer side of the tank.
            pill((x + side * 0.29, y, 0.0), (0.02, 0.03, 0.42), "glow", m["glow"], roundness=0.9)
        _nozzle(x, y, -0.62, g, m)
        if g.get("fins") == "small":
            pill((x + side * 0.3, y + 0.05, -0.5), (0.12, 0.025, 0.14), "trim", m["trim"], rotation=(0, side * 0.35, 0))
        elif g.get("fins") == "swept":
            wing(side, (x + side * 0.26, y + 0.05, -0.38), 0.32, 0.36, 0.06, 0.22, "trim", m["trim"], 0.05)
    if g.get("fairing"):
        # A nose cone over both tanks, like a comet's head.
        pill((0, y, 0.68), (0.72, 0.31, 0.16), "trim", m["trim"], roundness=0.95)
        sphere((0, y + 0.28, 0.68), 0.06, "glow", m["glow"])
    _straps(m)


def _engine(g, m):
    """A central engine: a housing between two pods, the core in the middle."""
    y = BACK + 0.12 + 0.3
    pill((0, BACK + 0.06, 0.0), (0.66, 0.06, 0.66), "trim", m["trim"])
    for side in (-1, 1):
        x = side * 0.48
        capsule((x, y, 0.0), 0.26, 1.25, "body", m["body"])
        cylinder((x, y, 0.5), 0.27, 0.07, "trim", m["trim"], bevel=0.015)
        if g.get("seam"):
            pill((x + side * 0.25, y, -0.05), (0.02, 0.03, 0.36), "glow", m["glow"], roundness=0.9)
        _nozzle(x, y, -0.55, g, m)
    if g.get("core") == "tube":
        # A glass tube of plasma: a hot core inside clear glass, capped top and bottom.
        cylinder((0, y + 0.02, 0.0), 0.08, 1.0, "glow", m["hot"], bevel=0)
        cylinder((0, y + 0.02, 0.0), 0.16, 1.0, "glass", m["glass"], bevel=0)
        for z in (0.53, -0.53):
            cylinder((0, y + 0.02, z), 0.19, 0.08, "metal", m["metal"])
    elif g.get("core") == "spine":
        pill((0, y + 0.05, 0.0), (0.13, 0.2, 0.62), "body", m["body"], roundness=0.8)
        for i in range(4):
            pill((0, y + 0.25, 0.36 - i * 0.24), (0.07, 0.015, 0.05), "glow", m["glow"], roundness=0.9)
    _straps(m)


def _lemniscate(center, width, height, thickness, mat, role):
    """An infinity loop standing upright (in the XZ plane), as a curve with a round section."""
    curve = bpy.data.curves.new("Infinity", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = thickness
    curve.bevel_resolution = _segments(4, 1)
    spline = curve.splines.new("POLY")
    count = _segments(96, 40)
    spline.points.add(count - 1)
    for i in range(count):
        t = i / count * 2 * math.pi
        d = 1 + math.sin(t) ** 2
        spline.points[i].co = (width * math.cos(t) / d, 0, height * math.sin(t) * math.cos(t) / d * 2, 1)
    spline.use_cyclic_u = True
    obj = bpy.data.objects.new("Infinity", curve)
    obj.location = center
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.select_set(False)
    return _tag(obj, role, mat)


def _hull(g, m, y):
    """The hull's shape differs by grade: a smooth capsule, a wedge with a dorsal fin, a slim
    streamlined pod."""
    hull = g.get("hull", "box")
    if hull == "round":
        capsule((0, y, 0.05), 0.55, 1.5, "body", m["body"])
        cylinder((0, y, 0.05), 0.57, 0.14, "trim", m["trim"], bevel=0.02)
        cylinder((0, y, -0.32), 0.57, 0.06, "trim", m["trim"], bevel=0.01)
    elif hull == "fin":
        pill((0, y, 0.05), (0.7, 0.28, 0.72), "body", m["body"], roundness=0.6)
        pill((0, y + 0.1, 0.05), (0.16, 0.22, 0.74), "trim", m["trim"], roundness=0.8)
        # A dorsal fin standing back from the spine.
        wing(1, (0, y + 0.28, 0.55), 0.0001, 0.5, 0.0, 0.0, "trim", m["trim"], 0.05)
        pill((0, y + 0.42, 0.35), (0.03, 0.18, 0.32), "trim", m["trim"], rotation=(math.radians(-25), 0, 0), roundness=0.8)
    elif hull == "slim":
        # Two slim pods joined by a saddle, streamlined top to bottom.
        for side in (-1, 1):
            capsule((side * 0.36, y, 0.05), 0.3, 1.55, "body", m["body"])
            capsule((side * 0.36, y + 0.12, 0.25), 0.16, 0.9, "trim", m["trim"])
        pill((0, y - 0.05, 0.05), (0.32, 0.18, 0.62), "trim", m["trim"], roundness=0.8)
    else:
        pill((0, y, 0.05), (0.72, 0.28, 0.72), "body", m["body"], roundness=0.75)
        pill((0, y + 0.1, 0.05), (0.2, 0.22, 0.74), "trim", m["trim"], roundness=0.8)
    if g.get("seam"):
        dx = 0.5 if hull == "round" else 0.36
        for side in (-1, 1):
            pill((side * dx * (0.9 if hull == "round" else 1), y + (0.2 if hull == "round" else 0.27), 0.05), (0.02, 0.02, 0.45), "glow", m["glow"], roundness=0.9)
    if g.get("lights"):
        for side in (-1, 1):
            sphere((side * 0.5, y + 0.24, 0.55), 0.05, "glow", m["hot"])


def _shell(g, m):
    """One hull over the back, the engines under it, wings and the legendary piece."""
    y = BACK + 0.3
    quad = g["nozzle"] == "quad"
    _hull(g, m, y)
    # Engine pods under the hull.
    xs = (-0.52, -0.18, 0.18, 0.52) if quad else (-0.4, 0.4)
    size = 0.8 if quad else 1.1 if g["nozzle"] == "big" else 1.0
    for x in xs:
        cylinder((x, y, -0.62), 0.17 * size, 0.18, "trim", m["trim"])
        _nozzle(x, y, -0.7, g, m, size)
    # Wings: from the top of the hull, out over the arms and back, a little up — clear of the
    # arms and of the camera behind.
    w = g.get("wings")
    if w:
        span, chord, sweep, rise = {
            "short": (0.45, 0.42, 0.12, 0.05),
            "swept": (0.7, 0.5, 0.2, 0.12),
            "blade": (0.8, 0.3, 0.25, 0.2),
            "long": (1.05, 0.42, 0.28, 0.18),
        }[w]
        for side in (-1, 1):
            root = (side * 0.6, y + 0.1, 0.45)
            wing(side, root, span, chord, sweep, -rise, "trim", m["trim"])
            # A glowing edge along the trailing side.
            wing(side, (root[0], root[1] + 0.02, root[2] - chord * 0.47), span * 0.95, 0.05, sweep * 0.95, -rise * 0.95, "glow", m["glow"], 0.07)
    core = g.get("core")
    top = Vector((0, y + 0.35, 0.25))
    if core == "orb":
        # Antimatter caged in glass on the upper back: a hot core, a glass ball, crossed rings.
        c = Vector((0, y + 0.4, 0.62))
        sphere(c, 0.15, "glow", m["hot"])
        sphere(c, 0.25, "glass", m["glass"])
        torus(c, 0.28, 0.028, "metal", m["metal"], rotation=(0, math.radians(90), 0))
        torus(c, 0.28, 0.028, "metal", m["metal"], rotation=(math.radians(90), 0, 0))
        cylinder((0, y + 0.3, 0.38), 0.08, 0.16, "metal", m["metal"])
    elif core == "hole":
        # A black sphere sitting on the upper back inside a flat glowing disc (seen edge-on from
        # behind it reads as a disc, not as an eye).
        c = Vector((0, y + 0.42, 0.62))
        sphere(c, 0.2, "trim", real.gloss("Void", (0.0, 0.0, 0.0), 0.05))
        torus(c, 0.55, 0.06, "glow", m["glow"], rotation=(math.radians(28), 0, 0))
        torus(c, 0.38, 0.04, "glow", m["hot"], rotation=(math.radians(28), 0, 0))
        cylinder((0, y + 0.3, 0.4), 0.08, 0.2, "metal", m["metal"])
    elif core == "portal":
        # A ring standing behind the back, glowing rings inside it (a swirl in the game).
        center = Vector((0, y + 0.42, 0.2))
        torus(center, 0.66, 0.07, "metal", m["metal"], rotation=(math.radians(90), 0, 0))
        for r, mat in ((0.58, m["glow"]), (0.42, m["hot"]), (0.26, m["glow"])):
            torus(center + Vector((0, 0.02, 0)), r, 0.022, "glow", mat, rotation=(math.radians(90), 0, 0))
        for side in (-1, 1):
            pill((side * 0.45, y + 0.25, -0.05), (0.05, 0.12, 0.05), "metal", m["metal"])
    elif core == "infinity":
        # An infinity loop standing over the back, gold with a glowing core.
        center = Vector((0, y + 0.3, 0.95))
        _lemniscate(center, 0.95, 0.4, 0.06, m["gold"], "trim")
        _lemniscate(center + Vector((0, 0.02, 0)), 0.95, 0.4, 0.026, m["hot"], "glow")
        cylinder((0, y + 0.3, 0.72), 0.05, 0.22, "metal", m["gold"])
    _straps(m)


def build(grade, location=(0, 0, 0), yaw=0.0):
    """Builds jetpack `grade` on a torso at `location` turned by `yaw` (radians, about Z).
    Returns the new objects."""
    before = set(bpy.data.objects)
    g = GRADES[grade]
    m = _materials(grade)
    {"tanks": _tanks, "engine": _engine, "shell": _shell}[g["form"]](g, m)
    placed = Matrix.Translation(Vector(location)) @ Matrix.Rotation(yaw, 4, "Z")
    new = [obj for obj in bpy.data.objects if obj not in before]
    for obj in new:
        obj.matrix_world = placed @ obj.matrix_world
    return new
