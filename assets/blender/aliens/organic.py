# The six alien families with organic bodies (decision 073): each body is melted together from
# balls (real.blob), so limbs, heads and tails flow into one form instead of separate spheres.
# A builder draws the baby at base point (x, 0, z) facing -Y with a body material and returns its
# anchors:
#   body      — the body mesh (for an aura shell round it);
#   top       — the highest point of the head, where a crest or a halo goes;
#   back      — points along the upper back, where growths (plates, crystals, fins) go;
#   center, radius — the body's middle and rough size, for effects round it;
#   width     — the radius of the tier ring under it.

import math

import bpy
import real

EYE = (0.01, 0.01, 0.02)


def alien_eye(location, size, iris):
    """A dark wet alien eye with a glowing ring of iris and a highlight."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=location)
    eye = bpy.context.active_object
    eye.scale = (size, size * 0.85, size)
    for poly in eye.data.polygons:
        poly.use_smooth = True
    real.assign(eye, real.gloss("Eye", EYE))
    x, y, z = location
    bpy.ops.mesh.primitive_torus_add(
        location=(x, y - size * 0.75, z), major_radius=size * 0.5, minor_radius=size * 0.1, rotation=(math.radians(90), 0, 0)
    )
    real.assign(bpy.context.active_object, real.glow("Iris", iris, 5.0))


def chain(points, radii):
    """Balls along a path, radius by radius: a limb, a tail, a stalk. Between the given points it
    adds balls closer than their radius, so the chain melts into one smooth limb."""
    balls = []
    for index in range(len(points) - 1):
        (ax, ay, az), (bx, by, bz) = points[index], points[index + 1]
        ra, rb = radii[index], radii[index + 1]
        length = math.dist((ax, ay, az), (bx, by, bz))
        steps = max(1, math.ceil(length / (min(ra, rb) * 0.45)))
        for step in range(steps):
            t = step / steps
            balls.append((ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t, ra + (rb - ra) * t))
    px, py, pz = points[-1]
    balls.append((px, py, pz, radii[-1]))
    return balls


def slime(x, z, mat, iris):
    # A heavy drop: a big round body, a rounded crown, and a base that spreads and sags.
    body = real.blob(
        [
            (0, 0, 0.85, 1.0),
            (0, 0.05, 1.45, 0.42),
            (-0.4, -0.1, 0.38, 0.6),
            (0.4, -0.1, 0.38, 0.6),
            (0.0, 0.35, 0.38, 0.6),
        ],
        mat, (x, 0, z), displace=0.03,
    )
    for dx, dz in ((-0.3, 1.08), (0.0, 1.2), (0.3, 1.08)):
        alien_eye((x + dx, -0.93, z + dz), 0.12, iris)
    return {"body": body, "top": (x, 0.05, z + 1.85), "center": (x, 0, z + 0.85), "radius": 1.0, "width": 1.35,
            "back": [(x + dx, 0.15 + dy, z + dz) for dx, dy, dz in ((0, 0.1, 1.82), (-0.45, 0.2, 1.62), (0.45, 0.2, 1.62), (-0.75, 0.25, 1.25), (0.75, 0.25, 1.25), (0, 0.55, 1.5), (-0.3, 0.6, 1.3), (0.3, 0.6, 1.3), (0, 0.75, 1.05))]}


def crab(x, z, mat, iris):
    elements = [(0, 0, 0.75, 0.75), (-0.45, 0.05, 0.72, 0.6), (0.45, 0.05, 0.72, 0.6), (0, -0.4, 0.7, 0.5), (0, 0.35, 0.72, 0.55)]
    for side in (-1, 1):
        # Short sturdy legs, bent at the knee.
        for index, y in enumerate((0.4, 0.1, -0.2)):
            elements += chain(
                [(side * 0.8, y, 0.65), (side * 1.12, y + 0.05, 0.72), (side * 1.32, y + 0.08, 0.35), (side * 1.38, y + 0.1, 0.06)],
                [0.17, 0.15, 0.12, 0.08],
            )
        elements += chain([(side * 0.7, -0.55, 0.8), (side * 1.05, -0.85, 0.92), (side * 1.25, -1.0, 1.0)], [0.2, 0.17, 0.17])
        elements.append((side * 1.42, -1.12, 1.08, 0.36, (1.0, 0.75, 0.7)))
        elements += chain([(side * 1.5, -1.38, 1.22), (side * 1.55, -1.6, 1.3)], [0.11, 0.06])
        elements += chain([(side * 1.38, -1.4, 0.95), (side * 1.42, -1.55, 0.92)], [0.09, 0.05])
        elements += chain([(side * 0.3, -0.5, 1.05), (side * 0.32, -0.58, 1.3), (side * 0.33, -0.62, 1.45)], [0.08, 0.07, 0.07])
    body = real.blob(elements, mat, (x, 0, z), displace=0.025)
    for side in (-1, 1):
        alien_eye((x + side * 0.33, -0.66, z + 1.58), 0.12, iris)
    return {"body": body, "top": (x, 0.1, z + 1.3), "center": (x, 0, z + 0.8), "radius": 1.1, "width": 1.7,
            "back": [(x + dx, dy, z + dz) for dx, dy, dz in ((0, 0.1, 1.18), (-0.45, 0.15, 1.12), (0.45, 0.15, 1.12), (-0.8, 0.2, 0.98), (0.8, 0.2, 0.98), (0, 0.45, 1.1), (-0.35, 0.5, 1.05), (0.35, 0.5, 1.05), (0, -0.25, 1.15))]}


def worm(x, z, mat, iris):
    path = [(1.0, 1.15, 0.24), (0.78, 0.85, 0.28), (0.55, 0.58, 0.34), (0.32, 0.32, 0.45), (0.12, 0.1, 0.62), (0.02, -0.08, 0.88), (0, -0.15, 1.18)]
    radii = [0.2, 0.28, 0.33, 0.38, 0.42, 0.47, 0.55]
    body = real.blob(chain(path, radii), mat, (x, 0, z), displace=0.02)
    for side in (-1, 1):
        alien_eye((x + side * 0.22, -0.66, z + 1.28), 0.11, iris)
    return {"body": body, "top": (x, -0.12, z + 1.78), "center": (x + 0.3, 0.3, z + 0.7), "radius": 0.9, "width": 1.3,
            "back": [(x + dx, dy, z + dz) for dx, dy, dz in ((0, -0.1, 1.72), (-0.2, 0.0, 1.6), (0.2, 0.0, 1.6), (0.12, 0.15, 1.12), (0.32, 0.38, 0.88), (0.55, 0.62, 0.7), (0.78, 0.88, 0.58), (1.0, 1.15, 0.46))]}


def ray(x, z, mat, iris):
    elements = [(0, 0.1, 0.85, 0.8, (1.0, 1.0, 0.6))]
    for side in (-1, 1):
        elements.append((side * 0.95, 0.25, 0.92, 0.85, (1.1, 0.75, 0.22)))
        elements.append((side * 1.6, 0.42, 1.2, 0.38, (1.0, 0.6, 0.22)))
        elements.append((side * 0.36, -0.68, 1.02, 0.16))
    elements += chain([(0, 0.85, 0.82), (0, 1.5, 0.78), (0, 2.1, 0.74), (0, 2.6, 0.72)], [0.16, 0.1, 0.07, 0.04])
    body = real.blob(elements, mat, (x, 0, z), displace=0.02)
    for side in (-1, 1):
        alien_eye((x + side * 0.28, -0.74, z + 1.05), 0.11, iris)
    return {"body": body, "top": (x, 0.1, z + 1.4), "center": (x, 0.2, z + 0.9), "radius": 1.2, "width": 1.9,
            "back": [(x + dx, dy, z + dz) for dx, dy, dz in ((0, 0.1, 1.35), (-0.6, 0.25, 1.2), (0.6, 0.25, 1.2), (-1.15, 0.35, 1.25), (1.15, 0.35, 1.25), (0, 0.5, 1.25), (-1.55, 0.45, 1.45), (1.55, 0.45, 1.45))]}


def wing(location, size, rotation, tint):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
    obj = bpy.context.active_object
    obj.scale = size
    obj.rotation_euler = rotation
    for poly in obj.data.polygons:
        poly.use_smooth = True
    real.assign(obj, real.iridescent("Wing", tint, transmission=0.85))
    return obj


def swarm(x, z, mat, iris):
    elements = [(0, -0.55, 1.1, 0.42), (0, 0, 1.0, 0.48), (0, 0.65, 0.85, 0.6, (0.9, 1.25, 0.9))]
    for side in (-1, 1):
        for y in (-0.15, 0.1, 0.35):
            elements += chain([(side * 0.35, y, 0.85), (side * 0.75, y - 0.05, 0.6), (side * 0.9, y - 0.1, 0.1)], [0.08, 0.06, 0.04])
        elements += chain([(side * 0.15, -0.8, 1.4), (side * 0.3, -0.95, 1.75), (side * 0.38, -1.0, 1.95)], [0.05, 0.04, 0.035])
    body = real.blob(elements, mat, (x, 0, z), displace=0.02)
    for side in (-1, 1):
        wing((x + side * 0.65, 0.25, z + 1.45), (0.65, 0.3, 0.06), (math.radians(-20), math.radians(side * -25), math.radians(side * 15)), (0.8, 0.9, 1.0))
        alien_eye((x + side * 0.24, -0.88, z + 1.15), 0.13, iris)
    return {"body": body, "top": (x, -0.5, z + 1.55), "center": (x, 0.1, z + 0.95), "radius": 1.0, "width": 1.35,
            "back": [(x + dx, dy, z + dz) for dx, dy, dz in ((0, -0.5, 1.5), (0, 0.0, 1.45), (0, 0.5, 1.4), (-0.3, 0.7, 1.3), (0.3, 0.7, 1.3), (0, 0.95, 1.2), (-0.3, -0.1, 1.38), (0.3, -0.1, 1.38))]}


def whale(x, z, mat, iris):
    elements = chain([(0, -0.3, 1.0), (0, 0.4, 1.0), (0, 1.0, 1.05), (0, 1.5, 1.2), (0, 1.8, 1.32)], [0.95, 0.85, 0.55, 0.32, 0.24])
    for side in (-1, 1):
        # Fluke and fins grown out of the body, not stuck on.
        elements += chain([(0, 1.8, 1.32), (side * 0.3, 1.95, 1.38), (side * 0.6, 2.05, 1.42)], [0.24, 0.2, 0.14])
        elements += chain([(side * 0.6, -0.15, 0.8), (side * 0.95, -0.1, 0.55), (side * 1.2, -0.05, 0.4)], [0.35, 0.22, 0.12])
    body = real.blob(elements, mat, (x, 0, z), displace=0.02)
    for side in (-1, 1):
        alien_eye((x + side * 0.42, -1.08, z + 1.08), 0.14, iris)
    return {"body": body, "top": (x, -0.1, z + 1.95), "center": (x, 0.2, z + 1.0), "radius": 1.2, "width": 1.6,
            "back": [(x + dx, dy, z + dz) for dx, dy, dz in ((0, -0.3, 1.92), (0, 0.25, 1.85), (-0.45, 0.0, 1.78), (0.45, 0.0, 1.78), (0, 0.8, 1.55), (-0.3, 0.6, 1.6), (0.3, 0.6, 1.6), (0, 1.3, 1.45))]}


FAMILIES = {"slime": slime, "crab": crab, "worm": worm, "ray": ray, "swarm": swarm, "whale": whale}
