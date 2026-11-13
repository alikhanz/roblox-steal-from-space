# The faceted low-poly style for models built from robo.py's primitives (decision 119): the same
# calls, the same layout, colours and roles, but every shape cut coarse and flat-shaded. A guardian
# or the serpent keeps its design and gains the style by swapping its primitives here:
#   sphere   -> an ico sphere (20, 80 or 320 faces by how fine the call asked for it);
#   cylinder -> a plain 6- or 8-sided prism, no bevel;
#   torus    -> 16 x 4;
#   pill     -> a box with a one-segment chamfer;
#   cone     -> a 6-sided pyramid;
#   blob     -> the metaball's elements as ico spheres, joined (a jelly of facets);
#   wing lines (curves) -> 4-sided tubes.
# `apply(module, ...)` swaps the names in each module given (robo's own calls and the modules that
# imported them with `from robo import ...`).

import bpy
import real
import robo


def _flat(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def sphere(location, scale, mat, segments=32, rotation=(0, 0, 0)):
    level = 3 if segments >= 48 else 2 if segments >= 24 else 1
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=level, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = scale
    return robo._tag(real.assign(_flat(obj), mat))


def cylinder(location, radius, depth, mat, rotation=(0, 0, 0), vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation,
                                        vertices=8 if vertices >= 24 else 6)
    return robo._tag(real.assign(_flat(bpy.context.active_object), mat))


def torus(location, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=location, major_radius=major, minor_radius=minor, rotation=rotation,
                                     major_segments=16, minor_segments=4)
    return robo._tag(real.assign(_flat(bpy.context.active_object), mat))


def pill(location, size, mat, rotation=(0, 0, 0), roundness=0.8):
    bpy.ops.mesh.primitive_cube_add(location=location, scale=size, rotation=rotation)
    obj = bpy.context.active_object
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = min(size) * min(roundness, 0.8) * 0.5
    bevel.segments = 1
    bevel.limit_method = "NONE"
    return robo._tag(real.assign(_flat(obj), mat))


def cone(location, radius, depth, mat, direction=(0, 0, 1)):
    from mathutils import Vector

    d = Vector(direction).normalized()
    centre = Vector(location) + d * depth / 2
    bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=0, depth=depth, location=tuple(centre), vertices=6)
    obj = bpy.context.active_object
    obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return robo._tag(real.assign(_flat(obj), mat))


def blob(elements, mat, location=(0, 0, 0), resolution=0.045, displace=0.0):
    """A metaball's elements (x, y, z, radius) as faceted balls joined into one object."""
    parts = []
    for x, y, z, r in elements:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r * 0.82,
                                              location=(location[0] + x, location[1] + y, location[2] + z))
        parts.append(_flat(bpy.context.active_object))
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    return real.assign(bpy.context.view_layer.objects.active, mat)


_wing_line = robo._wing_line


def wing_line(points, hinge, side, tilt, size, mat, radius):
    obj = _wing_line(points, hinge, side, tilt, size, mat, radius)
    obj.data.bevel_resolution = 0
    return obj


SHAPES = {"sphere": sphere, "cylinder": cylinder, "torus": torus, "pill": pill, "cone": cone}


def _no_subsurf(builder):
    """A builder's sheet (a guardian ray's wing) without its smoothing subdivision, flat-shaded."""

    def build(*args, **kwargs):
        obj = builder(*args, **kwargs)
        for modifier in list(obj.modifiers):
            if modifier.type == "SUBSURF":
                obj.modifiers.remove(modifier)
        return _flat(obj)

    return build


def apply(*modules):
    for module in modules:
        for name, function in SHAPES.items():
            if hasattr(module, name):
                setattr(module, name, function)
        if hasattr(module, "_wing_sheet"):
            module._wing_sheet = _no_subsurf(module._wing_sheet)
    real.blob = blob
    robo._wing_line = wing_line
