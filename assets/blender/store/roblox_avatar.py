# The standard Roblox character (R6) for the game page's pictures, read from the Roblox Studio
# install on this machine: the body meshes (content/avatar/meshes/*.mesh), the head
# (content/avatar/heads/head.mesh) and the classic face (content/textures/face.png). Nothing of it is
# copied into the repo; the renders only use it, as any Roblox game's thumbnail shows an avatar.
#
# Roblox mesh files "version 2.00": a text header line, then a little header (sizes, counts),
# vertices (position, normal, uv, maybe a colour) and triangles (indices).
# Axes: Roblox (x, y, z) with the face at −Z becomes Blender (−x, z, y) with the face at −Y.

import glob
import math
import os
import struct

import bpy
from mathutils import Matrix, Vector

LOCAL = os.environ.get("LOCALAPPDATA", "")

# R6 parts: centre in the character (Roblox studs, torso centre at the origin), size.
PARTS = {
    "Torso": ((0, 0, 0), (2, 2, 1), "meshes/torso.mesh"),
    "Left Arm": ((-1.5, 0, 0), (1, 2, 1), "meshes/leftarm.mesh"),
    "Right Arm": ((1.5, 0, 0), (1, 2, 1), "meshes/rightarm.mesh"),
    "Left Leg": ((-0.5, -2, 0), (1, 2, 1), "meshes/leftleg.mesh"),
    "Right Leg": ((0.5, -2, 0), (1, 2, 1), "meshes/rightleg.mesh"),
    # The head part is 2 × 1 × 1 with a Head mesh scaled 1.25: about 1.25 across.
    "Head": ((0, 1.5, 0), (1.25, 1.25, 1.25), "heads/head.mesh"),
}
# R6 joints (Motor6D), in the character: where each limb turns.
JOINTS = {
    "Head": (0, 1, 0),
    "Left Arm": (-1.5, 0.5, 0),
    "Right Arm": (1.5, 0.5, 0),
    "Left Leg": (-0.5, -1, 0),
    "Right Leg": (0.5, -1, 0),
}
# The classic look: yellow skin, blue shirt, green pants (Roblox's BrickColors Bright yellow,
# Bright blue, Dark green).
CLASSIC = {"skin": (245, 205, 48), "shirt": (13, 105, 172), "pants": (40, 127, 71)}


def content():
    """The newest Studio install's content folder that has the avatar meshes."""
    found = sorted(glob.glob(os.path.join(LOCAL, "Roblox", "Versions", "*", "content", "avatar", "meshes", "torso.mesh")),
                   key=os.path.getmtime)
    if not found:
        raise RuntimeError("Roblox Studio's avatar meshes not found under %LOCALAPPDATA%/Roblox/Versions")
    return os.path.dirname(os.path.dirname(os.path.dirname(found[-1])))


def to_blender(x, y, z):
    return Vector((-x, z, y))


def read_mesh(path):
    """Vertices (Roblox axes), normals, uvs and triangles of a version 2.00 mesh file."""
    data = open(path, "rb").read()
    header_end = data.index(b"\n") + 1
    assert data[:header_end].strip() == b"version 2.00", f"{path}: only version 2.00 meshes are read"
    header_size, vertex_size, face_size = struct.unpack_from("<HBB", data, header_end)
    vertex_count, face_count = struct.unpack_from("<II", data, header_end + 4)
    offset = header_end + header_size
    positions, normals, uvs = [], [], []
    for index in range(vertex_count):
        at = offset + index * vertex_size
        px, py, pz, nx, ny, nz, u, v, _ = struct.unpack_from("<9f", data, at)
        positions.append((px, py, pz))
        normals.append((nx, ny, nz))
        uvs.append((u, 1 - v))
    offset += vertex_count * vertex_size
    faces = [struct.unpack_from("<3I", data, offset + index * face_size) for index in range(face_count)]
    return positions, normals, uvs, faces


def srgb(rgb):
    return tuple((c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4 for c in rgb)


def plastic(name, rgb, roughness=0.42):
    """Roblox's SmoothPlastic, a touch glossier for the picture."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*srgb(rgb), 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Coat Weight"].default_value = 0.35
    return mat


def part(name, centre, size, mesh_path, mat):
    """One body part: the mesh scaled to the part's size, centred where R6 puts it."""
    positions, normals, uvs, faces = read_mesh(mesh_path)
    low = [min(p[i] for p in positions) for i in range(3)]
    high = [max(p[i] for p in positions) for i in range(3)]
    mid = [(low[i] + high[i]) / 2 for i in range(3)]
    scale = [size[i] / (high[i] - low[i]) for i in range(3)]
    if name == "Head":
        # Keep the head's own proportions: fit its width.
        k = size[0] / (high[0] - low[0])
        scale = [k, k, k]
    points = [to_blender(*[(p[i] - mid[i]) * scale[i] + centre[i] for i in range(3)]) for p in positions]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], [tuple(f) for f in faces])
    mesh.update()
    layer = mesh.uv_layers.new(name="UV")
    for poly in mesh.polygons:
        poly.use_smooth = True
        for loop in poly.loop_indices:
            layer.data[loop].uv = uvs[mesh.loops[loop].vertex_index]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def face_decal(head, root, radius, height, centre):
    """The classic smile on the head's front: the face texture on a band hugging the head."""
    image = bpy.data.images.load(os.path.join(root, "textures", "face.png"), check_existing=True)
    mat = bpy.data.materials.new("Face")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.extension = "CLIP"
    bsdf.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    bsdf.inputs["Roughness"].default_value = 0.5
    links.new(texture.outputs["Alpha"], bsdf.inputs["Alpha"])
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    # A cylinder band ±60° round the front, the decal's square mapped onto it.
    span = math.radians(60)
    steps = 24
    points, faces, uv = [], [], []
    for i in range(steps + 1):
        a = -span + 2 * span * i / steps
        for zi, z in enumerate((-height / 2, height / 2)):
            points.append(Vector((math.sin(a) * radius, -math.cos(a) * radius, z)) + centre)
            uv.append((i / steps, zi))
    for i in range(steps):
        faces.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
    mesh = bpy.data.meshes.new("Face")
    mesh.from_pydata(points, [], faces)
    layer = mesh.uv_layers.new(name="UV")
    for poly in mesh.polygons:
        poly.use_smooth = True
        for loop in poly.loop_indices:
            layer.data[loop].uv = uv[mesh.loops[loop].vertex_index]
    obj = bpy.data.objects.new("Face", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    obj.visible_shadow = False
    return obj


def build(colors=CLASSIC, pose=None):
    """The R6 character about its torso centre (Blender axes, facing −Y), posed by `pose`:
    {part name: (degrees about X, Y, Z) at its joint}. Returns {part name: [objects]}."""
    root = content()
    mats = {"skin": plastic("Skin", colors["skin"]), "shirt": plastic("Shirt", colors["shirt"]),
            "pants": plastic("Pants", colors["pants"])}
    which = {"Torso": "shirt", "Left Arm": "skin", "Right Arm": "skin", "Left Leg": "pants", "Right Leg": "pants",
             "Head": "skin"}
    parts = {}
    for name, (centre, size, mesh_file) in PARTS.items():
        obj = part(name, centre, size, os.path.join(root, "avatar", mesh_file), mats[which[name]])
        parts[name] = [obj]
    head = parts["Head"][0]
    bpy.context.view_layer.update()
    corners = [head.matrix_world @ Vector(c) for c in head.bound_box]
    radius = max(abs(c.y) for c in corners)
    low, high = min(c.z for c in corners), max(c.z for c in corners)
    parts["Head"].append(face_decal(head, root, radius + 0.012, (high - low) * 0.82, Vector((0, 0, (low + high) / 2))))
    for name, angles in (pose or {}).items():
        pivot = to_blender(*JOINTS[name])
        turn = Matrix.Translation(pivot) @ _rotation(angles) @ Matrix.Translation(-pivot)
        for obj in parts[name]:
            obj.matrix_world = turn @ obj.matrix_world
    bpy.context.view_layer.update()
    return parts


def _rotation(angles):
    from mathutils import Euler

    return Euler(tuple(math.radians(a) for a in angles), "XYZ").to_matrix().to_4x4()
