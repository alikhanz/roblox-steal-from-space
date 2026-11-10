# The guardians as grown-ups of their pets (decision 072: a pet is its guardian's baby). An adult
# is the same robot in the same zone finish and the guardian's colours, but built to threaten:
# longer and heavier, less baby roundness, armour plates, spikes and blades, a scowling visor
# whose eyes glow in the guardian's state colour (asleep, chasing, going home).
#
# A builder draws the adult at base point (x, 0, z) facing -Y, in baby units (the pets' scale in
# robo.py), and the caller grows it with robo._grow. Draft for the concept review.

import math

import real
import robo
import robo_kinds
from mathutils import Euler, Quaternion, Vector
from robo import cone, cylinder, glow, pill, sphere, torus

# Chase red: the state the player meets them in.
ALARM = (1.0, 0.02, 0.01)
# A glowing throat behind teeth.
MAW = (1.0, 0.22, 0.04)
WHITE_METAL = (0.85, 0.86, 0.9)


def eye_mat(colour=None):
    # Its own name: the game finds the eyes by it to colour them by state.
    return real.glow("GuardianEye", colour or ALARM, 4.0)


def metal():
    return real.chrome("Spike", WHITE_METAL, 0.2)


def visor_mat():
    return real.gloss("Visor", (0.012, 0.015, 0.02), 0.04)


def limb(a, b, radius, mat):
    """A cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    reach = b - a
    part = cylinder(tuple((a + b) / 2), radius, reach.length, mat)
    part.rotation_euler = reach.to_track_quat("Z", "Y").to_euler()
    return part


def spike(base, radius, length, mat, direction):
    return cone(tuple(base), radius, length, mat, tuple(direction))


def scowl(centre, width, height, theme, tilt=0.0, eyes=None):
    """A dark visor with slit eyes slanted down to the middle under a V of brow plates: the
    adult's scowl. `centre` is on the face, which looks towards -Y."""
    x, y, z = centre
    t = math.radians(tilt)
    pill((x, y, z), (width, 0.08, height), visor_mat(), (t, 0, 0), 0.5)
    for side in (-1, 1):
        slant = math.radians(-side * 22)
        sphere((x + side * width * 0.45, y - 0.085, z + height * 0.05), (width * 0.27, 0.025, height * 0.34), eye_mat(eyes), 24, (t, slant, 0))
        pill((x + side * width * 0.48, y - 0.07, z + height * 1.08), (width * 0.56, 0.1, height * 0.3), theme["accent_shell"](), (t, math.radians(-side * 24), 0), 0.35)


def oriented(obj, normal, twist=0.0):
    """Turns a part so its local -Y looks along `normal`, twisted about it by `twist` radians."""
    n = Vector(normal).normalized()
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Quaternion(n, twist) @ n.to_track_quat("-Y", "Z")
    return obj


def slit_eye(hull, point, side, size, brow, eyes=None):
    """One scowling eye on a curved hull (a whale's head): a socket, the slit and a heavy brow
    ridge, all lying on the surface at `point`."""
    location, normal = _surface(hull, point)
    twist = -side * math.radians(24)
    up = Quaternion(normal, twist) @ normal.to_track_quat("-Y", "Z") @ Vector((0, 0, 1))
    oriented(sphere(tuple(location), (size * 1.15, 0.05, size * 0.55), visor_mat(), 24), normal, twist)
    oriented(sphere(tuple(location + normal * 0.03), (size, 0.03, size * 0.32), eye_mat(eyes), 24), normal, twist)
    oriented(sphere(tuple(location + normal * 0.02 + up * size * 0.55), (size * 1.35, 0.12, size * 0.3), brow, 24), normal, twist)


def bpy_update():
    import bpy

    bpy.context.view_layer.update()


def _surface(obj, point):
    tree = robo._tree(obj)
    hit = tree.find_nearest(Vector(point))
    return hit[0], hit[1].normalized()


def on(obj, point, lift=0.0):
    """`point` moved onto `obj`'s surface, `lift` out along it."""
    location, normal = _surface(obj, point)
    return tuple(location + normal * lift)


# --- Slime: the warden ----------------------------------------------------------------------------


def slime(x, z, theme):
    """A tall jelly in a ribbed armoured cage on a heavy base, with gauntlets and a warden's lights."""
    shell = theme["shell"]()
    trim = theme["accent_shell"]
    accent = theme["accent"]
    cylinder((x, 0, z + 0.32), 1.05, 0.64, shell, vertices=48)
    # An armoured skirt of plates round the base, flaring out at the bottom.
    for index in range(14):
        angle = index / 14 * math.tau
        pill((x + math.cos(angle) * 1.06, math.sin(angle) * 1.06, z + 0.3), (0.2, 0.05, 0.3), shell,
             (math.radians(-14), 0, angle + math.pi / 2), 0.6)
    torus((x, 0, z + 0.66), 0.97, 0.12, trim())
    torus((x, 0, z + 0.48), 1.1, 0.035, glow(accent, 8.0))
    # Metal spikes round the collar, the face kept clear.
    for index in range(10):
        angle = index / 10 * math.tau
        if abs(math.remainder(angle + math.pi / 2, math.tau)) < 0.5:
            continue
        out = Vector((math.cos(angle), math.sin(angle), 0))
        spike(Vector((x, 0, z + 0.72)) + out * 0.95, 0.09, 0.42, metal(), out * 0.55 + Vector((0, 0, 1)))

    dome_z = z + 1.55
    real.blob([(0, 0, 0, 0.92), (0, 0, 0.55, 0.8), (0.12, 0.02, 1.05, 0.55), (-0.3, 0.1, 0.25, 0.6), (0.35, -0.05, 0.2, 0.55)],
              theme["core"](), (x, 0, z + 1.0), 0.045)
    tint = tuple(0.75 + 0.25 * c for c in theme["colours"]["core"])
    sphere((x, 0, dome_z), (0.95, 0.95, 1.15), robo.shell_glass("Dome", tint), 48)
    # The cage: three hoops over the dome make six ribs, none across the face.
    for turn in (0, 60, 120):
        rib = torus((x, 0, dome_z), 1.0, 0.06, shell, (math.radians(90), 0, math.radians(turn)))
        rib.scale = (1.0, 1.15, 1.0)
    torus((x, 0, dome_z - 0.45), 0.9, 0.04, glow(accent, 8.0))

    # The face right on the glass, the scowl over the jelly.
    scowl((x, -0.97, dome_z - 0.05), 0.46, 0.15, theme, -6)
    pill((x, -1.07, z + 0.32), (0.18, 0.04, 0.14), real.chrome("Badge", robo.GOLD, 0.25))

    # The warden's light bar on a cap where the ribs meet.
    top = dome_z + 1.15
    cylinder((x, 0, top), 0.32, 0.14, shell)
    pill((x, 0, top + 0.12), (0.5, 0.15, 0.09), real.gloss("Bar", (0.12, 0.13, 0.15), 0.3))
    for side, colour in ((-1, (1.0, 0.15, 0.15)), (1, (0.2, 0.45, 1.0))):
        sphere((x + side * 0.27, 0, top + 0.26), (0.17, 0.14, 0.14), real.glow("Siren", colour, 12.0), 16)

    # Shoulders with spiked pauldrons, and arms ending in heavy gauntlets.
    joint = real.gloss("Joint", (0.1, 0.11, 0.13), 0.25)
    for side in (-1, 1):
        shoulder = Vector((x + side * 1.12, -0.05, z + 1.0))
        sphere(tuple(shoulder), (0.3, 0.3, 0.3), shell, 24)
        pill(tuple(shoulder + Vector((side * 0.08, 0, 0.24))), (0.42, 0.36, 0.11), shell, (0, math.radians(side * 28), 0), 0.8)
        pill(tuple(shoulder + Vector((side * 0.1, 0, 0.32))), (0.3, 0.26, 0.05), trim(), (0, math.radians(side * 28), 0), 0.8)
        for dy in (-0.15, 0.18):
            spike(shoulder + Vector((side * 0.22, dy, 0.36)), 0.08, 0.4, metal(), (side * 0.7, 0, 1))
        elbow = shoulder + Vector((side * 0.4, -0.25, -0.45))
        sphere(tuple(elbow), (0.17, 0.17, 0.17), joint, 16)
        limb(shoulder, elbow, 0.13, shell)
        fist = elbow + Vector((side * -0.05, -0.45, -0.15))
        limb(elbow, fist, 0.12, shell)
        sphere(tuple(fist), (0.3, 0.32, 0.28), shell, 32)
        sphere(tuple(fist + Vector((0, -0.05, 0.12))), (0.22, 0.26, 0.12), trim(), 24)
        torus(tuple(fist + Vector((0, 0.2, 0))), 0.24, 0.03, glow(accent, 8.0), (math.radians(90), 0, 0))
        for dx in (-0.12, 0.0, 0.12):
            spike(fist + Vector((dx, -0.27, 0.04)), 0.05, 0.22, metal(), (0, -1, 0))


# --- Crab: the drone ------------------------------------------------------------------------------


def crab(x, z, theme):
    """A wide crab under a dark armoured carapace with a rim of metal spikes, stalk eyes over a
    scowl, three legs a side ending in metal tips, two big pincers and twin guarded rotors."""
    shell = theme["shell"]()
    trim = theme["accent_shell"]
    accent = theme["accent"]
    cz = z + 1.05
    body = sphere((x, 0, cz), (1.35, 1.0, 0.5), shell, 48)
    sphere((x, 0.15, cz + 0.2), (1.05, 0.78, 0.36), trim(), 48)
    rim = torus((x, 0, cz), 1.33, 0.035, glow(accent, 8.0))
    rim.scale = (1.0, 0.75, 1.0)
    # Metal spikes round the rim, the front kept clear; a short ridge down the back.
    for index in range(14):
        angle = index / 14 * math.tau
        if abs(math.remainder(angle + math.pi / 2, math.tau)) < 0.75:
            continue
        out = Vector((math.cos(angle) * 1.35, math.sin(angle) * 1.0, 0))
        spike(on(body, (x + out.x, out.y, cz + 0.05), -0.04), 0.07, 0.32, metal(), out.normalized() + Vector((0, 0, 0.25)))
    for dy in (0.0, 0.4, 0.75):
        spike(on(body, (x, dy, cz + 0.8), -0.03), 0.1, 0.42 - 0.08 * dy, metal(), (0, 0.6, 1))

    scowl((x, -1.0, cz + 0.02), 0.55, 0.16, theme, -8)
    joint = real.gloss("Joint", (0.1, 0.11, 0.13), 0.25)
    for side in (-1, 1):
        stalk = Vector((x + side * 0.42, -0.95, cz + 0.62))
        limb((x + side * 0.32, -0.72, cz + 0.3), stalk, 0.045, joint)
        sphere(tuple(stalk), (0.1, 0.1, 0.1), visor_mat(), 16)
        sphere(tuple(stalk + Vector((0, -0.06, 0))), (0.07, 0.05, 0.07), eye_mat(), 16)

    for side in (-1, 1):
        # Three legs a side: out to a knee, down to a metal tip.
        for dy in (-0.45, 0.05, 0.5):
            hip = Vector(on(body, (x + side * 1.3, dy, cz - 0.1), -0.05))
            knee = Vector((x + side * 1.95, dy * 1.15, cz + 0.5))
            foot = Vector((x + side * 2.85, dy * 1.45, z + 0.02))
            ankle = knee + (foot - knee) * 0.65
            sphere(tuple(hip), (0.14, 0.14, 0.14), joint, 16)
            limb(hip, knee, 0.11, shell)
            sphere(tuple(knee), (0.14, 0.14, 0.14), joint, 16)
            limb(knee, ankle, 0.09, shell)
            spike(ankle, 0.09, (foot - ankle).length, metal(), foot - ankle)
            torus(tuple(ankle), 0.095, 0.02, glow(accent, 8.0), tuple((foot - ankle).to_track_quat("Z", "Y").to_euler()))
        # A big pincer on an arm held up in front: a palm, a fixed lower finger and an open
        # upper one, both with metal tips.
        shoulder = Vector((x + side * 1.0, -0.7, cz - 0.05))
        elbow = Vector((x + side * 1.65, -1.2, cz + 0.15))
        palm = Vector((x + side * 1.35, -1.95, cz + 0.25))
        for a, b in ((shoulder, elbow), (elbow, palm)):
            limb(a, b, 0.13, shell)
        sphere(tuple(shoulder), (0.17, 0.17, 0.17), joint, 16)
        sphere(tuple(elbow), (0.17, 0.17, 0.17), joint, 16)
        toe_in = math.radians(-side * 12)
        sphere(tuple(palm), (0.42, 0.55, 0.38), shell, 32, (0, 0, toe_in))
        torus(tuple(palm + Vector((0, 0.42, 0))), 0.3, 0.03, glow(accent, 8.0), (math.radians(90), 0, 0))
        for offset, size, pitch, mat in (((side * 0.12, -0.55, -0.14), (0.14, 0.52, 0.13), 8, shell),
                                         ((-side * 0.04, -0.5, 0.16), (0.16, 0.6, 0.15), -16, trim())):
            turn = Euler((math.radians(pitch), 0, toe_in))
            centre = palm + Vector(offset)
            sphere(tuple(centre), size, mat, 32, tuple(turn))
            tip = centre + turn.to_matrix() @ Vector((0, -size[1] * 0.9, 0))
            spike(tip, 0.06, 0.22, metal(), turn.to_matrix() @ Vector((0, -1, 0)))
        for dy in (-0.1, 0.2):
            spike(palm + Vector((side * 0.15, dy, 0.33)), 0.06, 0.26, metal(), (side * 0.5, 0, 1))

    # Twin rotors behind guard rings, on masts from the back.
    mast = real.gloss("Mast", (0.15, 0.16, 0.18), 0.3)
    blade = real.gloss("Blade", (0.92, 0.93, 0.96), 0.2)
    for side in (-1, 1):
        rx, ry = x + side * 0.6, 0.55
        cylinder((rx, ry, cz + 0.75), 0.06, 0.7, mast)
        torus((rx, ry, cz + 1.1), 0.72, 0.045, trim())
        for spin in (25, 115):
            b = pill((rx, ry, cz + 1.12), (0.66, 0.08, 0.02), blade)
            b.rotation_euler = (math.radians(5), 0, math.radians(spin + side * 20))
        sphere((rx, ry, cz + 1.14), (0.11, 0.11, 0.07), glow(accent, 10.0), 16)


# --- Worm: the ice serpent ------------------------------------------------------------------------


WORM_SPINE = [(0.0, -0.15, 1.75, 0.6), (0.1, 0.3, 1.25, 0.58), (0.3, 0.72, 0.82, 0.56), (0.45, 1.12, 0.58, 0.53), (0.3, 1.55, 0.5, 0.5),
              (0.0, 1.95, 0.46, 0.46), (-0.3, 2.3, 0.42, 0.42), (-0.45, 2.65, 0.38, 0.37), (-0.4, 2.95, 0.34, 0.32)]


def worm(x, z, theme):
    """A long serpent rearing up: armoured segments with crystal spikes, an open jaw with
    mandibles and fangs, a crest of horns."""
    shell = theme["shell"]()
    trim = theme["accent_shell"]
    accent = theme["accent"]
    ice = real.crystal("Shard", theme["colours"]["glow"], 1.5)
    previous = None
    for px, py, pz, r in WORM_SPINE:
        centre = Vector((x + px, py, z + pz))
        sphere(tuple(centre), (r * 1.05, r * 0.9, r * 0.95), shell, 32)
        sphere(tuple(centre + Vector((0, 0.05, r * 0.7))), (r * 0.78, r * 0.5, r * 0.28), trim(), 32, (math.radians(-10), 0, 0))
        spike(centre + Vector((0, 0.1, r * 0.85)), r * 0.24, r * 1.0, ice, (0, 0.4, 1))
        for side in (-1, 1):
            spike(centre + Vector((side * r * 0.85, 0.05, r * 0.25)), r * 0.13, r * 0.5, ice, (side, 0.3, 0.5))
        if previous is not None:
            between = (previous + centre) / 2
            ring = torus(tuple(between), r * 0.82, 0.04, glow(accent, 8.0))
            ring.rotation_euler = (centre - previous).to_track_quat("Z", "Y").to_euler()
        previous = centre
    spike(previous + Vector((0, 0.2, 0)), 0.2, 0.8, ice, (0, 1, -0.1))

    hx, hy, hz = x, -0.6, z + 2.35
    sphere((hx, hy, hz), (0.62, 0.8, 0.55), shell, 48)
    sphere((hx, hy + 0.15, hz + 0.38), (0.48, 0.6, 0.22), trim(), 32, (math.radians(-8), 0, 0))
    # The open jaw, its throat glowing, mandibles out to the sides and fangs from the top.
    sphere((hx, hy - 0.25, hz - 0.45), (0.5, 0.6, 0.16), trim(), 32, (math.radians(16), 0, 0))
    sphere((hx, hy - 0.45, hz - 0.3), (0.32, 0.3, 0.13), theme["core"](), 24)
    fang = metal()
    for side in (-1, 1):
        spike((hx + side * 0.4, hy - 0.6, hz - 0.45), 0.1, 0.6, fang, (-side * 0.35, -1, 0.25))
        spike((hx + side * 0.2, hy - 0.62, hz - 0.18), 0.06, 0.32, fang, (0, -0.2, -1))
    scowl((hx, hy - 0.73, hz + 0.12), 0.45, 0.14, theme, -10)
    # A crest of crystal horns swept back.
    for dx, length in ((-0.3, 0.6), (0.0, 0.75), (0.3, 0.6)):
        spike((hx + dx, hy + 0.2, hz + 0.45), 0.12, length, ice, (dx * 0.9, 0.9, 0.5))


# --- Swarm: the hive ------------------------------------------------------------------------------


def wing_mat():
    return real.iridescent("Wing", (1.0, 0.8, 0.9), transmission=0.6)


def _hunter(x, y, z, size, theme, shell):
    """A little attack drone: a dark helmet, a metal sting, blade wings, a slit stare."""
    body = sphere((x, y, z), (0.32 * size, 0.42 * size, 0.28 * size), shell, 24)
    sphere((x, y + 0.05 * size, z + 0.1 * size), (0.26 * size, 0.34 * size, 0.2 * size), theme["accent_shell"](), 24)
    spike((x, y - 0.35 * size, z - 0.02 * size), 0.15 * size, 0.45 * size, metal(), (0, -1, -0.05))
    for side in (-1, 1):
        sphere((x + side * 0.12 * size, y - 0.33 * size, z + 0.06 * size), (0.09 * size, 0.02, 0.035 * size), eye_mat(), 12, (0, math.radians(-side * 25), 0))
        sphere((x + side * 0.5 * size, y + 0.1 * size, z + 0.25 * size), (0.5 * size, 0.16 * size, 0.015), wing_mat(), 16,
               (0, math.radians(-side * 30), math.radians(side * 25)))
    sphere((x, y + 0.42 * size, z), (0.1 * size, 0.04, 0.1 * size), glow(theme["accent"], 10.0), 12)
    return body


def swarm(x, z, theme):
    """A hive queen-drone: a helmeted thorax with jaws, a banded abdomen with a sting, four blade
    wings, and attack drones round her."""
    shell = theme["shell"]()
    trim = theme["accent_shell"]
    accent = theme["accent"]
    cz = z + 1.9
    thorax = sphere((x, 0, cz), (0.85, 0.8, 0.75), shell, 48)
    sphere((x, 0.12, cz + 0.32), (0.78, 0.72, 0.5), trim(), 48)
    # The abdomen hangs back and down, banded dark with glowing seams, a sting at its end.
    centre = Vector((x, 1.2, cz - 0.3))
    tilt = math.radians(-20)
    axis = Vector((0, math.cos(tilt), math.sin(tilt)))
    sphere(tuple(centre), (0.7, 1.05, 0.65), shell, 48, (tilt, 0, 0))
    band_turn = axis.to_track_quat("Z", "Y").to_euler()
    for t in (-0.45, -0.1, 0.25, 0.58):
        reach = math.sqrt(1 - t * t)
        torus(tuple(centre + axis * t * 1.05), 0.68 * reach, 0.07, trim(), tuple(band_turn))
        after = min(t + 0.1, 0.95)
        torus(tuple(centre + axis * after * 1.05), 0.68 * math.sqrt(1 - after * after), 0.025, glow(accent, 9.0), tuple(band_turn))
    spike(centre + axis * 1.0, 0.13, 0.75, metal(), axis + Vector((0, 0, -0.35)))
    sphere(on(thorax, (x, 0.0, cz - 0.9), -0.1), (0.45, 0.45, 0.15), theme["core"](), 24)

    scowl((x, -0.78, cz + 0.02), 0.5, 0.16, theme, -6)
    for side in (-1, 1):
        root = Vector((x + side * 0.35, -0.62, cz - 0.4))
        spike(root, 0.14, 0.55, metal(), (-side * 0.2, -1, -0.15))
        spike(root + Vector((-side * 0.1, -0.5, -0.07)), 0.09, 0.4, metal(), (-side * 1.0, -0.7, 0.0))
        spike(on(thorax, (x + side * 0.4, 0.0, cz + 0.9)), 0.1, 0.5, metal(), (side * 0.4, 0.5, 1))
        # Two pairs of blade wings, raised and swept back.
        for lift, reach, sweep, size in ((0.6, 1.3, 28, 1.0), (0.4, 1.05, 45, 0.75)):
            sphere((x + side * reach, 0.45 + 0.25 * (1 - size), cz + lift), (1.3 * size, 0.36 * size, 0.02), wing_mat(), 24,
                   (0, math.radians(-side * 22), math.radians(side * sweep)))
    spike(on(thorax, (x, 0.1, cz + 0.9)), 0.12, 0.6, metal(), (0, 0.4, 1))

    for dx, dy, dz, size in ((-2.1, -0.5, 1.0, 1.0), (2.2, -0.3, 0.8, 1.0), (-2.5, 0.7, -0.6, 0.85), (2.4, 0.9, -0.5, 0.9),
                             (-1.2, -1.3, -1.2, 0.8), (1.3, -1.4, -1.1, 0.85)):
        _hunter(x + dx, dy, cz + dz, size, theme, shell)


# --- Ray: the glider ------------------------------------------------------------------------------


# Half the wing's outline seen from above (x out, y back), the nose to the tail root.
RAY_OUTLINE = [(0.0, -0.9), (0.6, -0.95), (1.1, -0.7), (1.6, -0.35), (2.2, 0.15), (2.85, 0.62), (2.35, 0.72), (1.7, 0.62),
               (1.15, 0.7), (0.7, 0.95), (0.35, 1.15), (0.0, 1.2)]
RAY_TIP = 2.85


def _wing_height(reach):
    """How high the wing's middle stands at `reach` out from the body (the tips curl up)."""
    r = reach / RAY_TIP
    return 0.3 * r * r - 0.05 * r


def _wing_sheet(x, zc, mat, grow=1.0, thickness=0.2):
    import bmesh
    import bpy

    half = [(px * grow, py * grow + (grow - 1) * 0.1) for px, py in RAY_OUTLINE]
    outline = half + [(-px, py) for px, py in reversed(half[1:-1])]
    mesh = bpy.data.meshes.new("RayWing")
    bm = bmesh.new()
    verts = [bm.verts.new((x + px, py, 0)) for px, py in outline]
    bm.faces.new(verts)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    for v in bm.verts:
        v.co.z = zc + _wing_height(abs(v.co.x - x))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("RayWing", mesh)
    bpy.context.scene.collection.objects.link(obj)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 0.0
    sub = obj.modifiers.new("Subdivision", "SUBSURF")
    sub.levels = sub.render_levels = 2
    for poly in mesh.polygons:
        poly.use_smooth = True
    return robo._tag(real.assign(obj, mat))


def ray(x, z, theme):
    """A manta glider: wings swept to points over a glowing edge, gold horns forward, a ridge of
    spikes, a whip tail with a glowing blade, gold stars on the wings."""
    shell = theme["shell"]()
    accent = theme["accent"]
    zc = z + 1.2
    _wing_sheet(x, zc, shell)
    edge = theme["colours"]["core"]
    _wing_sheet(x, zc - 0.03, glow(edge, 4.0), 1.04, 0.05)
    sphere((x, 0.05, zc + 0.05), (0.72, 1.2, 0.36), shell, 48)
    sphere((x, 0.3, zc + 0.22), (0.38, 0.55, 0.2), theme["core"](), 32)
    gold = real.chrome("Horn", robo.GOLD, 0.25)
    star = real.chrome("Star", robo.GOLD, 0.25)
    for side in (-1, 1):
        spike((x + side * 0.42, -0.95, zc), 0.14, 0.75, gold, (side * 0.12, -1, 0.2))
        for reach, dy in ((1.0, -0.2), (1.6, 0.15), (2.2, 0.42)):
            robo_kinds.star(x + side * reach, dy, zc + _wing_height(reach) + 0.12, 0.1, star)
    for dy in (-0.55, -0.15, 0.25, 0.65):
        top = zc + 0.05 + 0.36 * math.sqrt(max(0.0, 1 - ((dy - 0.05) / 1.2) ** 2))
        spike((x, dy, top - 0.04), 0.09, 0.38, gold, (0, 0.6, 1))
    scowl((x, -1.12, zc + 0.02), 0.42, 0.12, theme, -10)

    # A whip tail of shrinking beads, ending in a glowing blade.
    for step in range(16):
        r = 0.13 - 0.0055 * step
        sphere((x, 1.15 + step * 0.15, zc - 0.02 * step), (r, r * 1.3, r), shell, 16)
    sphere((x, 3.75, zc - 0.32), (0.17, 0.42, 0.03), glow(edge, 5.0), 24)
    for side in (-1, 1):
        spike((x + side * 0.05, 1.25, zc + 0.1), 0.08, 0.4, metal(), (side * 0.8, 0.6, 0.4))


# --- Whale: the leviathan -------------------------------------------------------------------------


def whale(x, z, theme):
    """A long armoured leviathan: a flat head with an open maw full of metal teeth and a glowing
    throat, small deep-set eyes under heavy gold brows, horns swept back, a ridge of big spikes
    round a nebula window, clawed flippers and spiked flukes, twin thrusters."""
    shell = theme["shell"]()
    trim = theme["accent_shell"]
    accent = theme["accent"]
    gold = real.chrome("Armour", theme["colours"]["trim"], 0.25)
    cz = z + 1.3
    body = sphere((x, 0.5, cz), (1.0, 2.3, 0.85), shell, 48)
    sphere((x, 0.3, cz - 0.4), (0.82, 2.0, 0.5), trim(), 48)
    for dx in (-0.4, -0.13, 0.13, 0.4):
        limb((x + dx, -1.0, cz - 0.82), (x + dx, 1.5, cz - 0.84), 0.025, glow(accent, 6.0))

    # The head: a flat skull over a dropped jaw, the throat glowing between them.
    skull = sphere((x, -1.35, cz + 0.2), (0.95, 1.12, 0.6), shell, 48)
    jaw_tilt = math.radians(14)
    jaw = sphere((x, -1.2, cz - 0.55), (0.85, 1.05, 0.32), trim(), 48, (jaw_tilt, 0, 0))
    sphere((x, -1.65, cz - 0.38), (0.62, 0.55, 0.2), glow(MAW, 5.0), 32)
    # Teeth: down from the skull's rim, up from the jaw's, round the front.
    fang = metal()
    for index in range(9):
        angle = math.radians(-155 + index * (130 / 8))
        top = on(skull, (x + math.cos(angle) * 0.85, -1.35 + math.sin(angle) * 1.0, cz - 0.3), -0.02)
        spike(top, 0.06, 0.24 if index % 2 else 0.32, fang, (0, 0, -1))
        low = on(jaw, (x + math.cos(angle) * 0.72, -1.2 + math.sin(angle) * 0.9, cz - 0.3), -0.02)
        spike(low, 0.05, 0.2, fang, (0, -0.15, 1))

    for side in (-1, 1):
        slit_eye(skull, (x + side * 0.6, -1.95, cz + 0.32), side, 0.16, gold)
        # Horns swept back from the brow.
        spike(on(skull, (x + side * 0.5, -1.55, cz + 0.7), -0.03), 0.13, 0.8, gold, (side * 0.55, 0.7, 0.55))
    # A gold keel down the brow.
    sphere((x, -1.45, cz + 0.72), (0.14, 0.85, 0.16), gold, 32, (math.radians(-10), 0, 0))

    # A ridge of big spikes round the nebula window.
    sphere(on(body, (x, 0.7, cz + 1.0), -0.12), (0.38, 0.95, 0.18), theme["core"](), 32)
    for dy, length in ((-0.75, 0.55), (-0.2, 0.7), (1.6, 0.65), (2.15, 0.5), (2.6, 0.35)):
        spike(on(body, (x, dy, cz + 1.0), -0.04), 0.13, length, gold, (0, 0.45, 1))
    for side in (-1, 1):
        for dy, dz in ((-0.1, 0.4), (0.7, 0.45), (1.5, 0.35)):
            location, normal = _surface(body, (x + side * 1.1, dy, cz + dz))
            oriented(sphere(tuple(location), (0.7, 0.05, 0.08), gold, 32), normal)
        # Long flippers, angled down and swept back, glowing along the front, clawed behind.
        sweep = math.radians(side * 30)
        flipper = sphere((x + side * 1.4, -0.3, cz - 0.4), (0.82, 0.3, 0.06), shell, 32, (0, math.radians(side * 28), sweep))
        limb((x + side * 0.9, -0.55, cz - 0.15), (x + side * 2.0, 0.05, cz - 0.72), 0.03, glow(accent, 8.0))
        # Claws on the trailing edge, on its outer half (the flipper's own frame: its local +Y is
        # its back edge; the outer end is whichever end of local X lies further out).
        bpy_update()
        frame = flipper.matrix_world
        outer = 1 if (frame @ Vector((1, 0, 0))).x * side > (frame @ Vector((-1, 0, 0))).x * side else -1
        back = (frame.to_3x3() @ Vector((0, 1, 0))).normalized()
        for u in (0.3, 0.55, 0.8):
            root = frame @ Vector((outer * u, math.sqrt(1 - u * u) * 0.9, 0))
            spike(root, 0.05, 0.28, fang, back + Vector((side * 0.3, 0, 0)))
        # Flukes with spiked tips, and twin thrusters on the tail stock.
        sphere((x + side * 0.85, 3.25, cz + 0.15), (1.0, 0.34, 0.06), shell, 32, (0, 0, math.radians(side * 34)))
        spike((x + side * 1.6, 3.7, cz + 0.15), 0.07, 0.4, gold, (side * 0.85, 0.6, 0))
        cylinder((x + side * 0.4, 2.6, cz - 0.25), 0.18, 0.4, real.gloss("Engine", (0.1, 0.11, 0.13), 0.3), (math.radians(90), 0, 0))
        sphere((x + side * 0.4, 2.81, cz - 0.25), (0.14, 0.05, 0.14), glow(accent, 12.0), 24)
    sphere((x, 2.75, cz + 0.12), (0.38, 0.65, 0.3), shell, 32)
    star = real.glow("BackStar", (1.0, 0.95, 0.85), 12.0)
    for index in range(8):
        angle = index * 2.4
        sphere(on(body, (x + math.cos(angle) * 0.65, 0.7 + math.sin(angle) * 1.3, cz + 0.8), 0.01), (0.03,) * 3, star, 10)


# Each base and the post whose main kind is its baby (the six posts that set a body kind).
FAMILIES = {
    "slime": (slime, "slimeWarden", 2.2),
    "crab": (crab, "crabDrone", 2.0),
    "worm": (worm, "iceWorm", 2.0),
    "swarm": (swarm, "devourerSwarm", 1.9),
    "ray": (ray, "starRay", 2.0),
    "whale": (whale, "spaceWhale", 1.8),
}


def build(family, x, z):
    """The adult guardian of `family` (its post's colours and zone), grown to guardian size."""
    import bpy

    make, kind_id, growth = FAMILIES[family]
    kind = next(k for k in robo_kinds.KINDS if k[0] == kind_id)
    _, _, _, zone, look = kind[:5]
    before = set(bpy.data.objects)
    make(x, z, robo.theme(zone, look))
    robo._grow(set(bpy.data.objects) - before, x, z, growth)
    return kind
