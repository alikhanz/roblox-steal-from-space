# Concept (low-poly pets): the kit the low-poly directions are built from.
#
# A pet is a list of placements: a mesh from a shared library, a transform, a paint (a colour role
# and a Roblox-like material) and a game role. Meshes are never copied per pet: every placement of
# one mesh links the same Blender mesh datablock (one MeshId in Roblox), its size set by the
# object's scale (a MeshPart's Size; non-uniform is fine, mirrored never is). So the number of
# distinct datablocks in a scene is the number of meshes a player would download.
#
# Three styles shape the same primitives differently:
#   faceted - flat-shaded, low icospheres and chamfered blocks: a cut gem;
#   toy     - smooth-shaded, few segments, rounded blocks, no bevels: a vinyl toy;
#   sharp   - very few big flat faces, pointy accents: an angular mini figure.

import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

STYLES = ("faceted", "toy", "sharp")


# --- Geometry --------------------------------------------------------------------------------------


def _shade(bm, smooth, sharp_angle=0.75):
    for face in bm.faces:
        face.smooth = smooth
    if smooth:
        for edge in bm.edges:
            if edge.is_manifold and edge.calc_face_angle(0.0) > sharp_angle:
                edge.smooth = False


def _uv_ball(bm, segments, rings):
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)


def _ico(bm, level):
    bmesh.ops.create_icosphere(bm, subdivisions=level, radius=1.0)


def _can(bm, sides):
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=1.0, radius2=1.0, depth=2.0)


def _cone(bm, sides):
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=1.0, radius2=0.0, depth=1.0)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.5))


def _cube(bm):
    bmesh.ops.create_cube(bm, size=2.0)


def _chamfer_cube(bm, width=0.3):
    _cube(bm)
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=width, segments=1, affect="EDGES", profile=0.5)


def _rounded_box(bm, segments, rings, power=0.35):
    """A superellipsoid: a UV sphere pushed out towards a cube, a soft block with few faces."""
    _uv_ball(bm, segments, rings)
    for vert in bm.verts:
        vert.co = Vector(tuple(math.copysign(abs(c) ** power, c) for c in vert.co))


def _torus(bm, major, minor, thickness):
    rows = []
    for i in range(major):
        a = i / major * math.tau
        row = []
        for j in range(minor):
            b = j / minor * math.tau
            r = 1.0 + thickness * math.cos(b)
            row.append(bm.verts.new((r * math.cos(a), r * math.sin(a), thickness * math.sin(b))))
        rows.append(row)
    for i in range(major):
        for j in range(minor):
            a, b = rows[i][j], rows[(i + 1) % major][j]
            c, d = rows[(i + 1) % major][(j + 1) % minor], rows[i][(j + 1) % minor]
            bm.faces.new((a, b, c, d))


def _flat_ring(bm, sides, inner, depth=0.1):
    """A flat washer: a tier ring on the floor, a crown's band."""
    outer_bottom = [bm.verts.new((math.cos(i / sides * math.tau), math.sin(i / sides * math.tau), -depth)) for i in range(sides)]
    outer_top = [bm.verts.new((v.co.x, v.co.y, depth)) for v in outer_bottom]
    inner_bottom = [bm.verts.new((v.co.x * inner, v.co.y * inner, -depth)) for v in outer_bottom]
    inner_top = [bm.verts.new((v.co.x * inner, v.co.y * inner, depth)) for v in outer_bottom]
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((outer_bottom[i], outer_bottom[j], outer_top[j], outer_top[i]))
        bm.faces.new((inner_top[i], inner_top[j], inner_bottom[j], inner_bottom[i]))
        bm.faces.new((outer_top[i], outer_top[j], inner_top[j], inner_top[i]))
        bm.faces.new((inner_bottom[i], inner_bottom[j], outer_bottom[j], outer_bottom[i]))


def _prism(bm, outline, depth, fan_lift=0.0):
    """A flat outline (x, z) given thickness along y. `fan_lift` raises every other outline point
    out of the plane on both faces, so a fan of triangles from the root catches light like a gem."""
    count = len(outline)
    front, back = [], []
    for index, (x, z) in enumerate(outline):
        lift = fan_lift if index % 2 else 0.0
        front.append(bm.verts.new((x, -depth - lift, z)))
        back.append(bm.verts.new((x, depth + lift, z)))
    if fan_lift:
        root_front = bm.verts.new((outline[0][0], -depth, outline[0][1]))
        root_back = bm.verts.new((outline[0][0], depth, outline[0][1]))
        for i in range(1, count - 1):
            bm.faces.new((root_front, front[i + 1], front[i]))
            bm.faces.new((root_back, back[i], back[i + 1]))
        bm.faces.new((root_front, front[1], front[0]))
        bm.faces.new((root_back, back[0], back[1]))
        bm.faces.new((root_front, front[0], front[count - 1]))
        bm.faces.new((root_back, back[count - 1], back[0]))
    else:
        bm.faces.new(list(reversed(front)))
        bm.faces.new(back)
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def _frame(bm, outline, inset, depth):
    """A flat band along an outline (a wing's glowing edge): the outline and the same outline
    pulled towards its root by `inset`, with thickness."""
    rx, rz = outline[0]
    inner = [(rx + (x - rx) * inset, rz + (z - rz) * inset) for x, z in outline]
    count = len(outline)
    layers = []
    for y in (-depth, depth):
        layers.append(([bm.verts.new((x, y, z)) for x, z in outline], [bm.verts.new((x, y, z)) for x, z in inner]))
    (of, inf), (ob, inb) = layers
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new((of[i], of[j], inf[j], inf[i]))
        bm.faces.new((ob[i], inb[i], inb[j], ob[j]))
        bm.faces.new((of[i], ob[i], ob[j], of[j]))
        bm.faces.new((inf[i], inf[j], inb[j], inb[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def _chaikin(points, rounds):
    for _ in range(rounds):
        out = []
        for i in range(len(points)):
            (x0, y0), (x1, y1) = points[i], points[(i + 1) % len(points)]
            out += [(0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1), (0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1)]
        points = out
    return points


def _star(bm, points, inner, depth):
    """A flat star medal: `points` long rays, `inner` the valley radius."""
    outline = []
    for i in range(points * 2):
        a = i / (points * 2) * math.tau + math.pi / 2
        r = 1.0 if i % 2 == 0 else inner
        outline.append((r * math.cos(a), r * math.sin(a)))
    centre_f, centre_b = bm.verts.new((0, -depth * 2.5, 0)), bm.verts.new((0, depth, 0))
    front = [bm.verts.new((x, -depth, z)) for x, z in outline]
    back = [bm.verts.new((x, depth, z)) for x, z in outline]
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((centre_f, front[j], front[i]))
        bm.faces.new((centre_b, back[i], back[j]))
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


# The wing's key points (robo.WING_TRACE, the user's reference, 2026-11-08), root first.
def _wing_outline(style):
    import robo

    points = list(robo.WING_OUTLINE)
    if style == "toy":
        return [points[0]] + _chaikin(points, 1)[1:]
    if style == "sharp":
        # Every other key point: a few big angular lobes.
        keep = [0, 2, 3, 7, 8, 11, 12, 14, 16, 18, 19]
        return [points[i] for i in keep]
    return points


# --- Shapes per style -------------------------------------------------------------------------------
# Each entry builds a unit shape in a bmesh: balls and cans of radius 1 (cans 2 tall), cones 1 tall
# from their base, blocks 2 wide. Big parts (a body) take the "hi" balls, small ones the plain ones.

SHAPES = {
    "faceted": {
        "ball_hi": lambda bm: (_ico(bm, 2), _shade(bm, False)),
        "ball": lambda bm: (_ico(bm, 1), _shade(bm, False)),
        "dot": lambda bm: (_ico(bm, 1), _shade(bm, False)),
        "can": lambda bm: (_can(bm, 8), _shade(bm, False)),
        "cone": lambda bm: (_cone(bm, 6), _shade(bm, False)),
        "block": lambda bm: (_chamfer_cube(bm, 0.32), _shade(bm, False)),
        "ring": lambda bm: (_torus(bm, 12, 4, 0.08), _shade(bm, False)),
        "seam": lambda bm: (_torus(bm, 16, 3, 0.03), _shade(bm, False)),
        "washer": lambda bm: (_flat_ring(bm, 12, 0.82), _shade(bm, False)),
    },
    "toy": {
        "ball_hi": lambda bm: (_uv_ball(bm, 12, 7), _shade(bm, True)),
        "ball": lambda bm: (_uv_ball(bm, 8, 6), _shade(bm, True)),
        "dot": lambda bm: (_uv_ball(bm, 6, 4), _shade(bm, True)),
        "can": lambda bm: (_can(bm, 10), _shade(bm, True)),
        "cone": lambda bm: (_cone(bm, 10), _shade(bm, True)),
        "block": lambda bm: (_rounded_box(bm, 8, 6), _shade(bm, True, 1.4)),
        "ring": lambda bm: (_torus(bm, 12, 5, 0.1), _shade(bm, True)),
        "seam": lambda bm: (_torus(bm, 16, 3, 0.035), _shade(bm, True)),
        "washer": lambda bm: (_flat_ring(bm, 20, 0.82), _shade(bm, True)),
    },
    "sharp": {
        "ball_hi": lambda bm: (_uv_ball(bm, 8, 5), _shade(bm, False)),
        "ball": lambda bm: (_uv_ball(bm, 6, 4), _shade(bm, False)),
        "dot": lambda bm: (_uv_ball(bm, 4, 3), _shade(bm, False)),
        "can": lambda bm: (_can(bm, 6), _shade(bm, False)),
        "cone": lambda bm: (_cone(bm, 4), _shade(bm, False)),
        "block": lambda bm: (_cube(bm), _shade(bm, False)),
        "ring": lambda bm: (_torus(bm, 8, 3, 0.1), _shade(bm, False)),
        "seam": lambda bm: (_torus(bm, 8, 3, 0.04), _shade(bm, False)),
        "washer": lambda bm: (_flat_ring(bm, 8, 0.8), _shade(bm, False)),
    },
}

# How each style draws the face: eye size against the visor, a highlight, the eye's shape.
FACE = {
    # The user's pick (2026-11-13): the faceted style with the toy's big eyes and highlight.
    "faceted": {"eye": 1.35, "highlight": True},
    "toy": {"eye": 1.35, "highlight": True},
    "sharp": {"eye": 1.15, "highlight": False},
}


# --- Library -----------------------------------------------------------------------------------------


class Library:
    """Meshes by name, built once per style and shared by every placement. Bespoke dressing
    pieces (a crown, a wing, a jetpack tank) are composed from the style's shapes once, then
    shared like them."""

    def __init__(self, style):
        self.style = style
        self.meshes = {}
        self.placeholder = bpy.data.materials.get("Slot") or bpy.data.materials.new("Slot")

    def _new(self, name, fill):
        bm = bmesh.new()
        fill(bm)
        mesh = bpy.data.meshes.new(f"{self.style}:{name}")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(self.placeholder)
        return mesh

    def mesh(self, name):
        if name not in self.meshes:
            self.meshes[name] = self._new(name, self._builder(name))
        return self.meshes[name]

    def custom(self, name, fill):
        """A piece drawn by its own function (`fill` builds it into a bmesh), shared like the rest."""
        if name not in self.meshes:
            self.meshes[name] = self._new(name, fill)
        return self.meshes[name]

    def _shape(self, name):
        return SHAPES[self.style][name]

    def compose(self, name, pieces):
        """A bespoke piece from shapes: [(shape, location, scale, rotation)], baked into one mesh."""
        if name in self.meshes:
            return self.meshes[name]

        def fill(bm):
            for shape, location, scale, rotation in pieces:
                part = bmesh.new()
                self._shape(shape)(part)
                matrix = Matrix.LocRotScale(Vector(location), Euler(rotation).to_quaternion(), Vector(scale))
                bmesh.ops.transform(part, matrix=matrix, verts=part.verts)
                temp = bpy.data.meshes.new("temp")
                part.to_mesh(temp)
                part.free()
                bm.from_mesh(temp)
                bpy.data.meshes.remove(temp)

        self.meshes[name] = self._new(name, fill)
        return self.meshes[name]

    def _builder(self, name):
        style = self.style
        if name in SHAPES[style]:
            return self._shape(name)
        if name == "wing":
            outline = _wing_outline(style)
            return lambda bm: (_prism(bm, outline, 0.015, 0.05 if style == "faceted" else 0.0), _shade(bm, style == "toy", 1.0))
        if name == "wing_edge":
            outline = _wing_outline(style)
            return lambda bm: (_frame(bm, outline, 0.9, 0.022), _shade(bm, False))
        if name == "star":
            points = {"faceted": 8, "toy": 8, "sharp": 6}[style]
            return lambda bm: (_star(bm, points, 0.55, 0.03), _shade(bm, False))
        raise KeyError(name)


# --- Paint --------------------------------------------------------------------------------------------
# Materials as Roblox can show them: SmoothPlastic, Neon (flat glow), Glass (see-through) and the
# PetMetal variant (polished metal). One placement wears one paint, as a MeshPart has one Color and
# one Material.

_MATERIALS = {}


def paint(kind, colour):
    key = (kind, tuple(round(c, 3) for c in colour))
    if key in _MATERIALS:
        return _MATERIALS[key]
    mat = bpy.data.materials.new(f"{kind}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    if kind == "plastic":
        bsdf.inputs["Roughness"].default_value = 0.42
        bsdf.inputs["Specular IOR Level"].default_value = 0.45
    elif kind == "gloss":
        bsdf.inputs["Roughness"].default_value = 0.12
    elif kind == "neon":
        bsdf.inputs["Emission Color"].default_value = (*colour, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.8
    elif kind == "candy":
        bsdf.inputs["Metallic"].default_value = 0.7
        bsdf.inputs["Roughness"].default_value = 0.2
        bsdf.inputs["Coat Weight"].default_value = 1.0
    elif kind == "metal":
        bsdf.inputs["Metallic"].default_value = 1.0
        bsdf.inputs["Roughness"].default_value = 0.2
    elif kind == "glass":
        bsdf.inputs["Roughness"].default_value = 0.05
        bsdf.inputs["Alpha"].default_value = 0.35
        bsdf.inputs["Coat Weight"].default_value = 1.0
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
    elif kind == "glassglow":
        bsdf.inputs["Alpha"].default_value = 0.55
        bsdf.inputs["Emission Color"].default_value = (*colour, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.2
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
    mat.diffuse_color = (*colour, 1.0)
    _MATERIALS[key] = mat
    return mat


# --- Placing ------------------------------------------------------------------------------------------


class Pet:
    """One pet being placed: objects that link library meshes, each with its own paint."""

    def __init__(self, library, collection=None):
        self.library = library
        self.objects = []
        self.collection = collection or bpy.context.scene.collection

    def put(self, mesh, location, scale, material, rotation=(0, 0, 0), role="body"):
        if isinstance(scale, (int, float)):
            scale = (scale, scale, scale)
        assert min(scale) > 0, "a shared mesh is never mirrored (a MeshPart can't be)"
        data = self.library.mesh(mesh) if isinstance(mesh, str) else mesh
        obj = bpy.data.objects.new(data.name, data)
        self.collection.objects.link(obj)
        obj.location = location
        obj.scale = scale
        obj.rotation_euler = rotation
        obj.material_slots[0].link = "OBJECT"
        obj.material_slots[0].material = material
        obj["role"] = role
        self.objects.append(obj)
        return obj

    def grow(self, factor, origin=(0, 0, 0)):
        bpy.context.view_layer.update()
        pivot = Matrix.Translation(Vector(origin))
        scale = pivot @ Matrix.Diagonal(Vector((factor, factor, factor, 1.0))) @ pivot.inverted()
        for obj in self.objects:
            obj.matrix_world = scale @ obj.matrix_world

    def stats(self):
        triangles = 0
        for obj in self.objects:
            obj.data.calc_loop_triangles()
            triangles += len(obj.data.loop_triangles)
        return {"triangles": triangles, "parts": len(self.objects), "meshes": sorted({obj.data.name for obj in self.objects})}
