# The six alien families (decision 072): each guardian's babies are a slime, a crab, a worm, a
# ray, a swarm or a whale. A family builder draws the baby at base point (x, 0, z) facing -Y in
# a colour, and returns where things attach to it:
#   top        — where the legendary crown sits (crown_dx/dy/scale/tilt move it);
#   head       — the top of the head, for a kind's own headwear (a cap, flames, a bow);
#   center/radius — the body's middle and rough size, for details around it;
#   width      — the radius of the tier ring under it;
#   spots      — points on the body for the legendary gold spots.
# The tier outfit (ring, spots, crown, sparkles) is drawn here too, so every kind wears it alike.

import math

import bpy
import toon
from mathutils import Matrix, Vector

COMMON_RING = (0.70, 0.72, 0.78)
GOLD = (1.0, 0.74, 0.18)
# Each figure turns this far round its own axis (degrees) to show its volume.
YAW = -22


def lighter(color, amount=0.45):
    return tuple(c + (1 - c) * amount for c in color)


def darker(color, amount=0.35):
    return tuple(c * (1 - amount) for c in color)


def slime(x, z, color):
    body = toon.sphere("Body", (x, 0, z + 0.86), (1.0, 0.92, 0.84), color, 56)
    for vertex in body.data.vertices:
        if vertex.co.z < 0:
            sag = 1 + 0.16 * (-vertex.co.z)
            vertex.co.x *= sag
            vertex.co.y *= sag
    toon.face((x, -0.86, z + 1.0), 0.32, 1.0)
    return {"top": z + 1.66, "head": z + 1.62, "center": z + 0.86, "radius": 0.95, "width": 1.3,
            "spots": [(-0.7, -0.55, 1.3, 0.12), (0.62, -0.6, 1.35, 0.1), (0.8, -0.45, 0.62, 0.11), (0.1, -0.35, 1.62, 0.12)]}


def crab(x, z, color):
    toon.sphere("Shell", (x, 0, z + 0.78), (1.05, 0.78, 0.6), color, 48)
    # Eyes on stalks.
    for side in (-1, 1):
        toon.cylinder("Stalk", (x + side * 0.32, -0.25, z + 1.42), 0.07, 0.5, darker(color, 0.15))
        toon.sphere("EyeWhite", (x + side * 0.32, -0.3, z + 1.78), (0.22, 0.2, 0.24), toon.WHITE)
        toon.sphere("Pupil", (x + side * 0.32, -0.48, z + 1.76), (0.12, 0.05, 0.14), toon.BLACK)
        toon.sphere("Shine", (x + side * 0.28, -0.53, z + 1.82), (0.04, 0.02, 0.045), toon.WHITE, 16)
        # A chubby arm and a two-fingered claw.
        toon.sphere("Arm", (x + side * 1.12, -0.15, z + 0.85), (0.24, 0.24, 0.24), color)
        toon.sphere("Claw", (x + side * 1.42, -0.3, z + 1.18), (0.3, 0.26, 0.36), color)
        toon.cone("Pincer", (x + side * 1.5, -0.32, z + 1.58), 0.13, 0.36, color, (0, math.radians(side * -20), 0), 12)
        # Three little legs.
        for index in range(3):
            leg = toon.cylinder("Leg", (x + side * (0.65 + index * 0.18), 0.15 - index * 0.2, z + 0.2), 0.06, 0.45, darker(color, 0.15))
            leg.rotation_euler = (0, math.radians(side * 35), 0)
        toon.no_outline(toon.sphere("Cheek", (x + side * 0.55, -0.72, z + 0.75), (0.13, 0.04, 0.08), toon.CHEEK, 16, roughness=0.6, coat=0.0))
    smile = toon.torus("Smile", (x, -0.78, z + 0.8), 0.11, 0.028, toon.BLACK, (math.radians(90), 0, 0))
    for vertex in smile.data.vertices:
        if vertex.co.y > 0.0:
            vertex.co.y = 0.0
    toon.no_outline(smile)
    # Its crown sits tilted on the right eye: on the shell the eyes would hide it. Its own
    # headwear goes on the back of the shell, behind the eyes.
    return {"top": z + 2.04, "crown_dx": 0.32, "crown_dy": -0.3, "crown_scale": 0.78, "crown_tilt": -12,
            "head": z + 1.35, "head_dy": 0.25, "center": z + 0.78, "radius": 0.9, "width": 1.5,
            "spots": [(-0.55, -0.55, 1.1, 0.1), (0.5, -0.58, 1.05, 0.12), (0.0, -0.45, 1.25, 0.1)]}


def worm(x, z, color):
    # A curled tail of shrinking segments behind, a big raised head in front.
    for index, (dy, dz, r) in enumerate(((1.15, 0.28, 0.28), (0.8, 0.36, 0.36), (0.38, 0.48, 0.44))):
        toon.sphere("Segment", (x + 0.12 * math.sin(index * 1.4), dy, z + dz), (r, r, r), color if index % 2 else lighter(color, 0.15))
    toon.sphere("Head", (x, -0.15, z + 1.15), (0.66, 0.6, 0.62), color, 48)
    for side in (-1, 1):
        toon.cylinder("Antenna", (x + side * 0.22, -0.05, z + 1.85), 0.035, 0.32, darker(color, 0.2), (0, math.radians(side * 18), 0))
        toon.sphere("AntennaTip", (x + side * 0.28, -0.05, z + 2.02), (0.08, 0.08, 0.08), lighter(color, 0.5))
    toon.face((x, -0.72, z + 1.22), 0.24, 0.85)
    return {"top": z + 1.76, "head": z + 1.72, "center": z + 1.0, "radius": 0.7, "width": 1.1,
            "spots": [(-0.45, -0.5, 1.45, 0.09), (0.42, -0.52, 1.5, 0.08), (0.1, 0.0, 0.95, 0.1), (-0.2, 0.75, 0.68, 0.09)]}


def ray(x, z, color, star_color=None):
    # A plush baby manta: a round dome of a body with the face on its front, and two soft wings
    # out to the sides, swept back with their tips curling up, so it reads from the front.
    toon.sphere("Body", (x, 0.1, z + 0.85), (0.78, 0.82, 0.58), color, 48)
    stars = star_color or lighter(color, 0.75)
    for side in (-1, 1):
        wing = toon.sphere("Wing", (x + side * 1.05, 0.25, z + 0.95), (0.95, 0.7, 0.2), color, 40)
        for vertex in wing.data.vertices:
            reach = vertex.co.x * side
            if reach > 0:
                vertex.co.z += 0.9 * reach ** 2
        # Tilted toward the viewer, so the wing shows its top, not its edge.
        wing.rotation_euler = (math.radians(-32), 0, math.radians(side * -14))
        for dx, dy, dz in ((0.85, 0.2, 1.12), (1.3, 0.35, 1.3), (1.05, 0.55, 1.12)):
            toon.no_outline(toon.sphere("Star", (x + side * dx, dy, z + dz), (0.06, 0.06, 0.06), stars, 12, emission=0.6))
        # Little head fins, like a manta's.
        toon.cone("Horn", (x + side * 0.38, -0.55, z + 1.35), 0.09, 0.3, darker(color, 0.1), (math.radians(20), 0, math.radians(side * -25)), 12)
    toon.sphere("Belly", (x, -0.25, z + 0.62), (0.55, 0.5, 0.3), lighter(color, 0.4), 32)
    toon.cone("Tail", (x, 1.45, z + 0.75), 0.06, 1.2, darker(color, 0.15), (math.radians(-80), 0, 0), 12)
    toon.face((x, -0.7, z + 0.98), 0.26, 0.85)
    return {"top": z + 1.42, "head": z + 1.4, "center": z + 0.9, "radius": 0.75, "width": 1.9, "wings": True,
            "spots": [(-0.42, -0.55, 1.2, 0.08), (0.45, -0.52, 1.18, 0.08), (0.0, -0.3, 1.38, 0.08)]}


def bug(color, bx, bz, size, main):
    """One round bug with see-through wings; the main one has the full face."""
    toon.sphere("Bug", (bx, 0, bz), (0.72 * size, 0.66 * size, 0.7 * size), color, 40)
    for side in (-1, 1):
        wing = toon.sphere("Wing", (bx + side * 0.55 * size, 0.35 * size, bz + 0.5 * size), (0.42 * size, 0.06 * size, 0.28 * size), (0.85, 0.92, 1.0), 24, roughness=0.05, coat=1.0)
        wing.rotation_euler = (0, math.radians(side * -35), 0)
        toon.cylinder("Feeler", (bx + side * 0.2 * size, -0.2 * size, bz + 0.78 * size), 0.03 * size, 0.3 * size, darker(color, 0.3), (0, math.radians(side * 25), 0))
    if main:
        toon.face((bx, -0.64 * size, bz + 0.08 * size), 0.26 * size, 0.9 * size)
    else:
        for side in (-1, 1):
            toon.sphere("EyeWhite", (bx + side * 0.2 * size, -0.6 * size, bz + 0.1 * size), (0.18 * size, 0.08 * size, 0.22 * size), toon.WHITE)
            toon.sphere("Pupil", (bx + side * 0.2 * size, -0.68 * size, bz + 0.08 * size), (0.1 * size, 0.04 * size, 0.13 * size), toon.BLACK)


def swarm(x, z, color):
    # A round bug with see-through wings, and two tiny buddies buzzing around it.
    bug(color, x, z + 0.95, 1.0, True)
    bug(color, x - 1.1, z + 1.7, 0.42, False)
    bug(color, x + 1.05, z + 0.55, 0.38, False)
    return {"top": z + 1.68, "head": z + 1.64, "center": z + 0.95, "radius": 0.7, "width": 1.2,
            "spots": [(-0.45, -0.45, 1.25, 0.09), (0.48, -0.45, 1.2, 0.08), (0.0, -0.3, 1.55, 0.08)]}


def whale(x, z, color, belly=None):
    # A round baby whale facing you: a big head, a fluke curled up behind, little fins.
    toon.sphere("Body", (x, 0.15, z + 0.95), (1.15, 1.0, 0.85), color, 56)
    toon.sphere("Belly", (x, -0.35, z + 0.72), (0.85, 0.55, 0.55), belly or lighter(color, 0.45), 40)
    # The tail curls up behind the body; its fluke peeks out over the back to one side.
    toon.cylinder("TailStem", (x + 0.35, 1.0, z + 1.15), 0.2, 0.7, color, (math.radians(-40), 0, math.radians(-20)))
    for side in (-1, 1):
        fluke = toon.sphere("Fluke", (x + 0.55 + side * 0.32, 1.25, z + 1.55), (0.36, 0.12, 0.2), color, 32)
        fluke.rotation_euler = (math.radians(40), math.radians(side * 25), math.radians(-20))
        fin = toon.sphere("Fin", (x + side * 1.1, -0.1, z + 0.55), (0.35, 0.16, 0.14), color, 24)
        fin.rotation_euler = (0, math.radians(side * 30), 0)
    # A tiny spout of stars.
    for dx, dz, size in ((0.55, 2.0, 0.11), (0.4, 2.15, 0.08), (0.7, 2.18, 0.07)):
        toon.sphere("Spout", (x + dx, 0.0, z + dz), (size, size, size), lighter(color, 0.7), 16)
    toon.face((x, -0.83, z + 1.12), 0.34, 1.0)
    return {"top": z + 1.82, "head": z + 1.78, "center": z + 0.95, "radius": 1.0, "width": 1.4,
            "spots": [(-0.65, -0.55, 1.45, 0.09), (0.6, -0.58, 1.48, 0.1), (-0.95, -0.2, 1.05, 0.08), (0.95, -0.2, 1.0, 0.08)]}


FAMILIES = {"slime": slime, "crab": crab, "worm": worm, "ray": ray, "swarm": swarm, "whale": whale}


def ring(x, z, width, color):
    toon.torus("Ring", (x, 0, z + 0.03), width, 0.07, color, emission=0.3)


def lean(objects, pivot_point, degrees, axis="Y"):
    """Turns freshly made `objects` round `pivot_point`."""
    # New objects' matrices only include their scale once the scene is updated.
    bpy.context.view_layer.update()
    pivot = Matrix.Translation(Vector(pivot_point))
    turn = pivot @ Matrix.Rotation(math.radians(degrees), 4, axis) @ pivot.inverted()
    for obj in objects:
        obj.matrix_world = turn @ obj.matrix_world


def crown(cx, cy, top, scale, tilt):
    """A gold crown with six tips and a gem, `scale` times the usual size, leaning `tilt` degrees."""
    before = set(bpy.data.objects)
    toon.cylinder("Crown", (cx, cy, top), 0.38 * scale, 0.16 * scale, GOLD)
    for index in range(6):
        angle = math.radians(index * 60 + 90)
        toon.cone("CrownTip", (cx + 0.34 * scale * math.cos(angle), cy + 0.34 * scale * math.sin(angle), top + 0.2 * scale), 0.08 * scale, 0.24 * scale, GOLD)
    toon.sphere("Gem", (cx, cy - 0.38 * scale, top), (0.08 * scale, 0.05 * scale, 0.08 * scale), (0.95, 0.15, 0.4), 16)
    if tilt:
        lean(set(bpy.data.objects) - before, (cx, cy, top), tilt)


def legendary_outfit(x, z, info):
    # Gold spots, like the crown.
    for dx, dy, dz, size in info["spots"]:
        toon.no_outline(toon.sphere("Spot", (x + dx, dy, z + dz), (size, size * 0.6, size * 0.9), GOLD, 16, emission=0.15))
    crown(x + info.get("crown_dx", 0.0), info.get("crown_dy", 0.0), info["top"], info.get("crown_scale", 1.0), info.get("crown_tilt", 0))
    for px, pz, size in ((-1.55, 1.7, 0.13), (1.6, 1.9, 0.15), (-1.7, 0.75, 0.1), (1.65, 0.6, 0.11)):
        for spin in (0, 45):
            toon.cone("Sparkle", (x + px, -0.9, z + pz), size, size * 0.2, GOLD, (math.radians(90), 0, math.radians(spin)), 4, emission=1.5)


def turned(x, z, make):
    """Builds a figure with `make` and turns it a little round its own axis, so a straight
    camera sees it three-quarter while rows of figures stay level."""
    before = set(bpy.data.objects)
    info = make()
    lean(set(bpy.data.objects) - before, (x, 0, z), YAW, "Z")
    return info
