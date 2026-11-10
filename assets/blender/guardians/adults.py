# The guardians as grown-ups of their pets (decision 072: a pet is its guardian's baby). An adult
# is the same robot in the same zone finish and the guardian's colours, but built to threaten:
# longer and heavier, less baby roundness, armour plates, spikes and blades, a scowling visor
# whose eyes glow in the guardian's state colour (asleep, chasing, going home).
#
# Each post's adult is grown from its main kind (robo_kinds.py): the same family, colours, shape
# parameters (a tall acid slime, a crab with one huge claw) and signature parts. A builder draws
# the adult at base point (x, 0, z) facing -Y and returns the same anchors as a pet family
# (robo.py: shells, hull, top, centre, radius...), so the pets' signature parts sit on it too.
# They are sized for a pet, so they are put on while the adult is shrunk to a pet's size
# (FAMILIES' `pet_scale`); a few signatures have adult versions of their own (ADULT_SIGNATURES).

import math

import bpy
import real
import robo
import robo_kinds
from mathutils import Euler, Quaternion, Vector
from robo import cone, cylinder, gem, glow, pill, sphere, torus

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


def spikes_of(zone):
    """What an adult's spikes are made of: ice in the Ice Rings, metal elsewhere."""
    if zone == "ice":
        return lambda theme: real.crystal("Shard", theme["colours"]["glow"], 1.5)
    return lambda theme: metal()


def limb(a, b, radius, mat):
    """A cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    reach = b - a
    part = cylinder(tuple((a + b) / 2), radius, reach.length, mat)
    part.rotation_euler = reach.to_track_quat("Z", "Y").to_euler()
    return part


def spike(base, radius, length, mat, direction):
    return cone(tuple(base), radius, length, mat, tuple(direction))


def hinge(name, point):
    """The point a moving part turns about: a tiny marker in role `hinge<Name>` (`hingeArmL` turns
    `armL`), which the unpacking turns into an attachment (BLENDER_ROBLOX.md, section 3)."""
    with robo.role("hinge" + name):
        sphere(tuple(point), (0.03, 0.03, 0.03), real.gloss("Joint", (0.1, 0.11, 0.13), 0.25), 8)


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


def _surface(obj, point):
    tree = robo._tree(obj)
    hit = tree.find_nearest(Vector(point))
    return hit[0], hit[1].normalized()


def on(obj, point, lift=0.0):
    """`point` moved onto `obj`'s surface, `lift` out along it."""
    location, normal = _surface(obj, point)
    return tuple(location + normal * lift)


# --- Slime: the warden ----------------------------------------------------------------------------


def slime(x, z, theme, p, zone):
    """A jelly in a ribbed armoured cage on a heavy base, with gauntlets. p: w (width), h (height)."""
    w, h = p.get("w", 1.0), p.get("h", 1.0)
    shell = theme["shell"]()
    trim = theme["accent_shell"]
    accent = theme["accent"]
    spiked = spikes_of(zone)
    base = cylinder((x, 0, z + 0.32), 1.05 * w, 0.64, shell, vertices=48)
    # An armoured skirt of plates round the base, flaring out at the bottom.
    for index in range(14):
        angle = index / 14 * math.tau
        pill((x + math.cos(angle) * 1.06 * w, math.sin(angle) * 1.06 * w, z + 0.3), (0.2 * w, 0.05, 0.3), shell,
             (math.radians(-14), 0, angle + math.pi / 2), 0.6)
    torus((x, 0, z + 0.66), 0.97 * w, 0.12, trim())
    torus((x, 0, z + 0.48), 1.1 * w, 0.035, glow(accent, 8.0))
    # Spikes round the collar, the face kept clear.
    for index in range(10):
        angle = index / 10 * math.tau
        if abs(math.remainder(angle + math.pi / 2, math.tau)) < 0.5:
            continue
        out = Vector((math.cos(angle), math.sin(angle), 0))
        spike(Vector((x, 0, z + 0.72)) + out * 0.95 * w, 0.09, 0.42, spiked(theme), out * 0.55 + Vector((0, 0, 1)))

    dome_z = z + 0.4 + 1.15 * h
    jelly = [(0, 0, 0, 0.92), (0, 0, 0.55, 0.8), (0.12, 0.02, 1.05, 0.55), (-0.3, 0.1, 0.25, 0.6), (0.35, -0.05, 0.2, 0.55)]
    if h > 1.2:
        jelly.append((0.0, 0.0, 1.55, 0.45))
    real.blob([(ex * w, ey * w, ez * h, r * min(w, h)) for ex, ey, ez, r in jelly], theme["core"](), (x, 0, z + 0.55 + 0.45 * h), 0.045 / robo.DETAIL)
    tint = tuple(0.75 + 0.25 * c for c in theme["colours"]["core"])
    dome = sphere((x, 0, dome_z), (0.95 * w, 0.95 * w, 1.15 * h), robo.shell_glass("Dome", tint), 48)
    # The cage: three hoops over the dome make six ribs, none across the face.
    for turn in (0, 60, 120):
        rib = torus((x, 0, dome_z), 1.0 * w, 0.06, shell, (math.radians(90), 0, math.radians(turn)))
        rib.scale = (1.0, 1.15 * h / w, 1.0)
    torus((x, 0, dome_z - 0.45 * h), 0.9 * w, 0.04, glow(accent, 8.0))

    # The face right on the glass, the scowl over the jelly.
    scowl((x, -0.97 * w, dome_z - 0.05), 0.46 * min(w, 1.15), 0.15, theme, -6)

    # Shoulders with spiked pauldrons, and arms ending in heavy gauntlets.
    joint = real.gloss("Joint", (0.1, 0.11, 0.13), 0.25)
    shells = [base]
    for side in (-1, 1):
        shoulder = Vector((x + side * 1.12 * w, -0.05, z + 1.0))
        shells.append(sphere(tuple(shoulder), (0.3, 0.3, 0.3), shell, 24))
        pauldron = pill(tuple(shoulder + Vector((side * 0.08, 0, 0.24))), (0.42, 0.36, 0.11), shell, (0, math.radians(side * 28), 0), 0.8)
        pill(tuple(shoulder + Vector((side * 0.1, 0, 0.32))), (0.3, 0.26, 0.05), trim(), (0, math.radians(side * 28), 0), 0.8)
        for dy in (-0.15, 0.18):
            spike(on(pauldron, tuple(shoulder + Vector((side * 0.22, dy, 0.6))), -0.03), 0.08, 0.4, spiked(theme), (side * 0.7, 0, 1))
        # The arm swings from the shoulder (role armL / armR).
        name = "L" if side < 0 else "R"
        with robo.role("arm" + name):
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
        hinge("Arm" + name, shoulder)
    return {"shells": shells, "top": (x, 0, dome_z + 1.15 * h), "center": (x, 0, dome_z - 0.1), "radius": 0.95 * w, "width": 1.2 * w,
            "hull": ((x, 0, dome_z), (0.95 * w, 0.95 * w, 1.15 * h)), "hull_obj": dome}


def siren(info, theme):
    """The warden's light bar on a cap where the cage's ribs meet."""
    tx, ty, tz = info["top"]
    cylinder((tx, ty, tz), 0.32, 0.14, theme["shell"]())
    pill((tx, ty, tz + 0.12), (0.5, 0.15, 0.09), real.gloss("Bar", (0.12, 0.13, 0.15), 0.3))
    for side, colour in ((-1, (1.0, 0.15, 0.15)), (1, (0.2, 0.45, 1.0))):
        sphere((tx + side * 0.27, ty, tz + 0.26), (0.17, 0.14, 0.14), real.glow("Siren", colour, 12.0), 16)
    # A gold badge on the front of the base (the first shell).
    base = info["shells"][0]
    pill(on(base, tuple(base.location - Vector((0, 2.0, 0))), 0.02), (0.18, 0.04, 0.14), real.chrome("Badge", robo.GOLD, 0.25))


# --- Crab: the drone ------------------------------------------------------------------------------


CRAB_LEGS = {2: (-0.3, 0.35), 3: (-0.45, 0.05, 0.5), 4: (-0.55, -0.2, 0.15, 0.5)}


def crab(x, z, theme, p, zone):
    """A wide crab under a dark armoured carapace with a rim of spikes, stalk eyes over a scowl,
    legs ending in metal tips and pincers. p: w (width), claws (left, right sizes), legs (per
    side), boxy (a blocky tank hull)."""
    w = p.get("w", 1.0)
    claws = p.get("claws", (1.0, 1.0))
    legs = CRAB_LEGS[min(4, max(2, p.get("legs", 3)))]
    shell = theme["shell"]()
    trim = theme["accent_shell"]
    accent = theme["accent"]
    spiked = spikes_of(zone)
    cz = z + 1.05
    if p.get("boxy"):
        body = pill((x, 0, cz), (1.35 * w, 1.0, 0.5), shell, roundness=0.45)
        pill((x, 0.15, cz + 0.4), (1.0 * w, 0.75, 0.16), trim(), roundness=0.6)
    else:
        body = sphere((x, 0, cz), (1.35 * w, 1.0, 0.5), shell, 48)
        sphere((x, 0.15, cz + 0.2), (1.05 * w, 0.78, 0.36), trim(), 48)
    rim = torus((x, 0, cz), 1.33 * w, 0.035, glow(accent, 8.0))
    rim.scale = (1.0, 0.75 / w, 1.0)
    # Spikes round the rim, the front kept clear; a short ridge down the back.
    for index in range(14):
        angle = index / 14 * math.tau
        if abs(math.remainder(angle + math.pi / 2, math.tau)) < 0.75:
            continue
        out = Vector((math.cos(angle) * 1.35 * w, math.sin(angle) * 1.0, 0))
        spike(on(body, (x + out.x, out.y, cz + 0.05), -0.04), 0.07, 0.32, spiked(theme), out.normalized() + Vector((0, 0, 0.25)))
    for dy in (0.0, 0.4, 0.75):
        spike(on(body, (x, dy, cz + 0.8), -0.03), 0.1, 0.42 - 0.08 * dy, spiked(theme), (0, 0.6, 1))

    scowl((x, -1.0, cz + 0.02), 0.55, 0.16, theme, -8)
    joint = real.gloss("Joint", (0.1, 0.11, 0.13), 0.25)
    for side in (-1, 1):
        stalk = Vector((x + side * 0.42, -0.95, cz + 0.62))
        limb((x + side * 0.32, -0.72, cz + 0.3), stalk, 0.045, joint)
        sphere(tuple(stalk), (0.1, 0.1, 0.1), visor_mat(), 16)
        sphere(tuple(stalk + Vector((0, -0.06, 0))), (0.07, 0.05, 0.07), eye_mat(), 16)

    shells = [body]
    for side in (-1, 1):
        # Legs out to a knee, down to a metal tip. Each is a role of its own (legLA… from the
        # front back), hinged at its hip, so the game can make the crab step, as a pet's.
        name = "L" if side < 0 else "R"
        for index, dy in enumerate(legs):
            hip = Vector(on(body, (x + side * 1.3 * w, dy, cz - 0.1), -0.05))
            knee = Vector((x + side * (1.95 * w), dy * 1.15, cz + 0.5))
            foot = Vector((x + side * (2.25 * w + 0.6), dy * 1.45, z + 0.02))
            ankle = knee + (foot - knee) * 0.65
            sphere(tuple(hip), (0.14, 0.14, 0.14), joint, 16)
            with robo.role("leg" + name + "ABCD"[index]):
                limb(hip, knee, 0.11, shell)
                sphere(tuple(knee), (0.14, 0.14, 0.14), shell, 16)
                limb(knee, ankle, 0.09, shell)
                spike(ankle, 0.09, (foot - ankle).length, metal(), foot - ankle)
            hinge("Leg" + name + "ABCD"[index], hip)
        # A pincer on an arm held up in front: a palm, a fixed lower finger and an open upper one,
        # both with metal tips. A kind may grow one much bigger.
        size = claws[0] if side < 0 else claws[1]
        if size <= 0:
            continue
        grow = size - 1
        shoulder = Vector((x + side * 1.0 * w, -0.7, cz - 0.05))
        elbow = Vector((x + side * (1.65 * w + 0.2 * grow), -1.2 - 0.15 * grow, cz + 0.15 + 0.1 * grow))
        palm = Vector((x + side * (1.35 * w + 0.35 * grow), -1.95 - 0.45 * grow, cz + 0.25 + 0.25 * grow))
        for a, b in ((shoulder, elbow), (elbow, palm)):
            limb(a, b, 0.13 * max(1.0, size * 0.8), shell)
        sphere(tuple(shoulder), (0.17, 0.17, 0.17), joint, 16)
        sphere(tuple(elbow), (0.17, 0.17, 0.17), joint, 16)
        toe_in = math.radians(-side * 12)
        hand = sphere(tuple(palm), (0.42 * size, 0.55 * size, 0.38 * size), shell, 32, (0, 0, toe_in))
        shells.append(hand)
        torus(tuple(palm + Vector((0, 0.42 * size, 0))), 0.3 * size, 0.03, glow(accent, 8.0), (math.radians(90), 0, 0))
        # The fingers snap as a pet's jaws: jawBot (the fixed lower one) and jawTop, on a hinge
        # inside the palm's front.
        for offset, finger, pitch, mat, jaw in (((side * 0.12, -0.55, -0.14), (0.14, 0.52, 0.13), 8, shell, "jawBot"),
                                                ((-side * 0.04, -0.5, 0.16), (0.16, 0.6, 0.15), -16, trim(), "jawTop")):
            turn = Euler((math.radians(pitch), 0, toe_in))
            centre = palm + Vector(offset) * size
            finger = tuple(f * size for f in finger)
            with robo.role(jaw + name):
                sphere(tuple(centre), finger, mat, 32, tuple(turn))
                tip = centre + turn.to_matrix() @ Vector((0, -finger[1] * 0.9, 0))
                spike(tip, 0.06 * size, 0.22 * size, metal(), turn.to_matrix() @ Vector((0, -1, 0)))
        hinge("Jaw" + name, palm + Vector((0, -0.3 * size, 0)))
        for dy in (-0.1, 0.2):
            spike(on(hand, tuple(palm + Vector((side * 0.15, dy, 0.6)) * size), -0.03), 0.06, 0.26, spiked(theme), (side * 0.5, 0, 1))
    return {"shells": shells, "top": (x, 0.1, cz + 0.9), "center": (x, 0, cz), "radius": 1.3 * w, "width": 1.9 * w,
            "hull": ((x, 0, cz), (1.35 * w, 1.0, 0.5)), "hull_obj": body}


def rotors(info, theme):
    """Twin rotors behind guard rings, on masts from the back."""
    (cx, cy, cz) = info["center"]
    mast = real.gloss("Mast", (0.15, 0.16, 0.18), 0.3)
    blade = real.gloss("Blade", (0.92, 0.93, 0.96), 0.2)
    for side in (-1, 1):
        rx, ry = cx + side * 0.6, cy + 0.55
        cylinder((rx, ry, cz + 0.75), 0.06, 0.7, mast)
        torus((rx, ry, cz + 1.1), 0.72, 0.045, theme["accent_shell"]())
        # Each rotor spins about its own parts' middle (rotorL, rotorR).
        with robo.role("rotor" + ("L" if side < 0 else "R")):
            for spin in (25, 115):
                b = pill((rx, ry, cz + 1.12), (0.66, 0.08, 0.02), blade)
                b.rotation_euler = (math.radians(5), 0, math.radians(spin + side * 20))
            sphere((rx, ry, cz + 1.14), (0.11, 0.11, 0.07), glow(theme["accent"], 10.0), 16)


# --- Worm: the serpent ----------------------------------------------------------------------------


# The spine from under the head back to the tail's end: (x, y, z, radius).
WORM_SPINE = [(0.0, -0.15, 1.75, 0.6), (0.1, 0.3, 1.25, 0.58), (0.3, 0.72, 0.82, 0.56), (0.45, 1.12, 0.58, 0.53), (0.3, 1.55, 0.5, 0.5),
              (0.0, 1.95, 0.46, 0.46), (-0.3, 2.3, 0.42, 0.42), (-0.45, 2.65, 0.38, 0.37), (-0.4, 2.95, 0.34, 0.32),
              (-0.2, 3.22, 0.3, 0.28), (0.05, 3.45, 0.27, 0.24)]


def worm(x, z, theme, p, zone):
    """A long serpent rearing up: armoured segments with spikes, an open jaw with mandibles and
    fangs, a crest of horns. p: segments (the pet's; the adult has four more), r (thickness),
    faceted (crystal segments)."""
    count = min(len(WORM_SPINE), max(8, p.get("segments", 5) + 4))
    rs = p.get("r", 1.0)
    faceted = p.get("faceted", False)
    shell = theme["shell"]()
    trim = theme["accent_shell"]
    accent = theme["accent"]
    spiked = spikes_of(zone)
    shells = []
    previous = None
    for index, (px, py, pz, r) in enumerate(WORM_SPINE[:count]):
        r *= rs
        centre = Vector((x + px, py * max(1.0, rs * 0.9), z + max(pz, r * 0.95)))
        # The segments with what they wear make six roles (segA under the head to segF at the tail),
        # so the game runs a wave down the worm, as a pet's, with few parts to move.
        with robo.role("seg" + "ABCDEF"[index * 6 // count]):
            if faceted:
                segment = gem(tuple(centre), (r * 1.1, r, r * 1.15), shell, (0.3 * index, 0.5, 0.2 * index))
                sphere(tuple(centre), (r * 0.45,) * 3, theme["core"](), 16)
            else:
                segment = sphere(tuple(centre), (r * 1.05, r * 0.9, r * 0.95), shell, 32)
                sphere(tuple(centre + Vector((0, 0.05, r * 0.7))), (r * 0.78, r * 0.5, r * 0.28), trim(), 32, (math.radians(-10), 0, 0))
            shells.append(segment)
            spike(on(segment, tuple(centre + Vector((0, 0.1, r * 1.5))), -0.03), r * 0.24, r * 1.0, spiked(theme), (0, 0.4, 1))
            for side in (-1, 1):
                spike(on(segment, tuple(centre + Vector((side * r * 1.5, 0.05, r * 0.45))), -0.03), r * 0.13, r * 0.5, spiked(theme), (side, 0.3, 0.5))
            if previous is not None and not faceted:
                between = (previous + centre) / 2
                ring = torus(tuple(between), r * 0.82, 0.04, glow(accent, 8.0))
                ring.rotation_euler = (centre - previous).to_track_quat("Z", "Y").to_euler()
            if index == count - 1:
                spike(centre + Vector((0, 0.2, 0)), 0.2 * rs, 0.8, spiked(theme), (0, 1, -0.1))
        previous = centre

    hs = min(rs, 1.25)
    hx, hy, hz = x, -0.6, z + 2.35 + 0.4 * (rs - 1)
    head_r = 0.62 * hs
    if faceted:
        head = gem((hx, hy, hz), (0.62 * hs, 0.8 * hs, 0.55 * hs), shell, (0.2, 0.4, 0.1))
    else:
        head = sphere((hx, hy, hz), (0.62 * hs, 0.8 * hs, 0.55 * hs), shell, 48)
        sphere((hx, hy + 0.15, hz + 0.38 * hs), (0.48 * hs, 0.6 * hs, 0.22 * hs), trim(), 32, (math.radians(-8), 0, 0))
    # The neck: the head and all it wears turn about its centre as the worm looks round.
    hinge("Head", (hx, hy, hz))
    # The open jaw with its mandibles (role jaw, hinged at its back), the throat glowing behind
    # it, fangs from the top.
    with robo.role("jaw"):
        sphere((hx, hy - 0.25 * hs, hz - 0.45 * hs), (0.5 * hs, 0.6 * hs, 0.16 * hs), trim(), 32, (math.radians(16), 0, 0))
        for side in (-1, 1):
            spike((hx + side * 0.4 * hs, hy - 0.6 * hs, hz - 0.45 * hs), 0.1 * hs, 0.6 * hs, metal(), (-side * 0.35, -1, 0.25))
    hinge("Jaw", (hx, hy + 0.25 * hs, hz - 0.4 * hs))
    sphere((hx, hy - 0.45 * hs, hz - 0.3 * hs), (0.32 * hs, 0.3 * hs, 0.13 * hs), real.glow("Maw", MAW, 4.0), 24)
    for side in (-1, 1):
        spike((hx + side * 0.2 * hs, hy - 0.62 * hs, hz - 0.18 * hs), 0.06 * hs, 0.32 * hs, metal(), (0, -0.2, -1))
    scowl((hx, hy - 0.73 * hs, hz + 0.12 * hs), 0.45 * hs, 0.14 * hs, theme, -10)
    # A crest of horns swept back.
    for dx, length in ((-0.3, 0.6), (0.0, 0.75), (0.3, 0.6)):
        spike((hx + dx * hs, hy + 0.2 * hs, hz + 0.45 * hs), 0.12 * hs, length * hs, spiked(theme), (dx * 0.9, 0.9, 0.5))
    return {"shells": shells + [head], "top": (hx, hy, hz + 0.55 * hs + 0.3), "center": (x + 0.15, 1.0, z + 1.0), "radius": 0.95 * rs, "width": 1.4 * rs,
            "head": (hx, hy, hz), "head_r": head_r,
            "hull": ((hx, hy, hz), (0.62 * hs, 0.8 * hs, 0.55 * hs)), "flank": (hx, hy, hz - 0.1), "flank_r": head_r * 1.2, "hull_obj": head}


# --- Swarm: the hive ------------------------------------------------------------------------------


def wing_mat():
    return real.iridescent("Wing", (1.0, 0.8, 0.9), transmission=0.6)


def _hunter(x, y, z, size, theme, shell):
    """A little attack drone: a dark helmet, a metal sting, blade wings, a slit stare. Its wings
    are vanes, not "Wing": they do not buzz, so they join the other hunters' glass."""
    body = sphere((x, y, z), (0.32 * size, 0.42 * size, 0.28 * size), shell, 24)
    sphere((x, y + 0.05 * size, z + 0.1 * size), (0.26 * size, 0.34 * size, 0.2 * size), theme["accent_shell"](), 24)
    spike((x, y - 0.35 * size, z - 0.02 * size), 0.15 * size, 0.45 * size, metal(), (0, -1, -0.05))
    vane = real.iridescent("Vane", (1.0, 0.8, 0.9), transmission=0.6)
    for side in (-1, 1):
        sphere((x + side * 0.12 * size, y - 0.33 * size, z + 0.06 * size), (0.09 * size, 0.02, 0.035 * size), eye_mat(), 12, (0, math.radians(-side * 25), 0))
        sphere((x + side * 0.42 * size, y + 0.1 * size, z + 0.22 * size), (0.5 * size, 0.16 * size, 0.015), vane, 16,
               (0, math.radians(-side * 30), math.radians(side * 25)))
    sphere((x, y + 0.42 * size, z), (0.1 * size, 0.04, 0.1 * size), glow(theme["accent"], 10.0), 12)
    return body


# Where the hunters fly round the queen (x, y, z from her thorax, size), in the order they join.
HUNTER_SPOTS = [(-2.1, -0.5, 1.0, 1.0), (2.2, -0.3, 0.8, 1.0), (-2.5, 0.7, -0.6, 0.85), (2.4, 0.9, -0.5, 0.9),
                (-1.2, -1.3, -1.2, 0.8), (1.3, -1.4, -1.1, 0.85), (0.0, 1.2, 1.6, 0.8)]


def swarm(x, z, theme, p, zone):
    """A hive queen-drone: a helmeted thorax with jaws, a banded abdomen with a sting, four blade
    wings, and attack drones round her. p: main (her size), count (the hunters)."""
    q = p.get("main", 1.2) / 1.2
    shell = theme["shell"]()
    trim = theme["accent_shell"]
    accent = theme["accent"]
    spiked = spikes_of(zone)
    cz = z + 0.8 + 1.1 * q
    thorax = sphere((x, 0, cz), (0.85 * q, 0.8 * q, 0.75 * q), shell, 48)
    sphere((x, 0.12 * q, cz + 0.32 * q), (0.78 * q, 0.72 * q, 0.5 * q), trim(), 48)
    # The abdomen hangs back and down, banded dark with glowing seams, a sting at its end.
    centre = Vector((x, 1.2 * q, cz - 0.3 * q))
    tilt = math.radians(-20)
    axis = Vector((0, math.cos(tilt), math.sin(tilt)))
    abdomen = sphere(tuple(centre), (0.7 * q, 1.05 * q, 0.65 * q), shell, 48, (tilt, 0, 0))
    band_turn = axis.to_track_quat("Z", "Y").to_euler()
    for t in (-0.45, -0.1, 0.25, 0.58):
        torus(tuple(centre + axis * t * 1.05 * q), 0.68 * q * math.sqrt(1 - t * t), 0.07 * q, trim(), tuple(band_turn))
        after = min(t + 0.1, 0.95)
        torus(tuple(centre + axis * after * 1.05 * q), 0.68 * q * math.sqrt(1 - after * after), 0.025, glow(accent, 9.0), tuple(band_turn))
    spike(centre + axis * 1.0 * q, 0.13 * q, 0.75 * q, metal(), axis + Vector((0, 0, -0.35)))
    sphere(on(thorax, (x, 0.0, cz - 0.9), -0.1), (0.45 * q, 0.45 * q, 0.15 * q), theme["core"](), 24)

    scowl((x, -0.78 * q, cz + 0.02), 0.5 * q, 0.16 * q, theme, -6)
    for side in (-1, 1):
        name = "L" if side < 0 else "R"
        # The jaws snap as a devourer pet's mandibles (mandL, mandR, hinged at their root).
        root = Vector((x + side * 0.35 * q, -0.62 * q, cz - 0.4 * q))
        with robo.role("mand" + name):
            spike(root, 0.14 * q, 0.55 * q, metal(), (-side * 0.2, -1, -0.15))
            spike(root + Vector((-side * 0.1, -0.5, -0.07)) * q, 0.09 * q, 0.4 * q, metal(), (-side * 1.0, -0.7, 0.0))
        hinge("Mand" + name, root)
        spike(on(thorax, (x + side * 0.4 * q, 0.0, cz + 0.9)), 0.1 * q, 0.5 * q, spiked(theme), (side * 0.4, 0.5, 1))
        # Two pairs of blade wings, raised and swept back, buzzing from their roots (buzzL, buzzR).
        with robo.role("buzz" + name):
            for lift, reach, sweep, size in ((0.6, 1.3, 28, 1.0), (0.4, 1.05, 45, 0.75)):
                sphere((x + side * reach * q, (0.45 + 0.25 * (1 - size)) * q, cz + lift * q), (1.3 * size * q, 0.36 * size * q, 0.02), wing_mat(), 24,
                       (0, math.radians(-side * 22), math.radians(side * sweep)))
        hinge("Buzz" + name, (x + side * 0.3 * q, 0.45 * q, cz + 0.5 * q))
    spike(on(thorax, (x, 0.1, cz + 0.9)), 0.12 * q, 0.6 * q, spiked(theme), (0, 0.4, 1))

    # The hunters fly round her as one flock (role hunters): one set of parts for them all, so a
    # phone draws a handful of meshes for the whole swarm, not a few per drone.
    reach = max(q, 0.9)
    with robo.role("hunters"):
        for dx, dy, dz, size in HUNTER_SPOTS[:p.get("count", 3) + 3]:
            _hunter(x + dx * reach, dy * reach, cz + dz * reach, size, theme, shell)
    return {"shells": [thorax, abdomen], "top": (x, 0, cz + 0.85 * q), "center": (x, 0, cz), "radius": 0.9 * q, "width": 1.0 * q,
            "lead": (x, 0, cz), "lead_size": 0.85 * q / 0.55, "engine_z": -0.05,
            "hull": ((x, 0, cz), (0.85 * q, 0.8 * q, 0.75 * q)), "shoulders": False, "hull_obj": thorax}


def no_mandibles(info, theme):
    """An adult swarm has its own jaws."""


def queen(info, theme):
    """A queen's crest and glowing brood pods under her (her jaws are the adult's own)."""
    robo_kinds.crest(info, theme)
    (lx, ly, lz), size = robo_kinds._lead(info)
    snap = robo._flank(info)[2]
    pod = real.jelly("Brood", theme["colours"]["core"], glow=3.0, clear=True)
    for dx, dy in ((-0.35, 0.1), (0.0, 0.25), (0.35, 0.1)):
        sphere(snap((lx + dx * size, ly + dy, lz - 0.75 * size), 0.06), (0.14, 0.14, 0.18), pod, 20)


# --- Ray: the glider ------------------------------------------------------------------------------


# Half the wing's outline seen from above (x out, y back), the nose to the tail root, at span 1.
RAY_OUTLINE = [(0.0, -0.9), (0.6, -0.95), (1.1, -0.7), (1.6, -0.35), (2.2, 0.15), (2.85, 0.62), (2.35, 0.72), (1.7, 0.62),
               (1.15, 0.7), (0.7, 0.95), (0.35, 1.15), (0.0, 1.2)]
RAY_TIP = 2.85


def _wing_height(reach, span, droop):
    """How high the wing's middle stands `reach` out from the body: the tips curl up on a flat
    ray, down on one with a deep droop."""
    r = reach / (RAY_TIP * span)
    return (0.35 - 0.025 * droop) * r * r - 0.05 * r


def _wing_sheet(x, zc, mat, span, droop, side, grow=1.0, thickness=0.2):
    """One wing (side -1 or 1): the outline's half, its root edge inside the body so the halves
    meet there, raised by the wing's curl, thickened and smoothed."""
    import bmesh

    half = [(px * span * grow, py * grow + (grow - 1) * 0.1) for px, py in RAY_OUTLINE]
    # The root runs inside the body, clear of its middle (the two wings beat apart).
    half[0] = (0.3, half[0][1])
    half[-1] = (0.3, half[-1][1])
    mesh = bpy.data.meshes.new("RayWing")
    bm = bmesh.new()
    verts = [bm.verts.new((x + side * px, py, 0)) for px, py in half]
    bm.faces.new(verts if side > 0 else list(reversed(verts)))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    for v in bm.verts:
        v.co.z = zc + _wing_height(abs(v.co.x - x), span, droop)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("RayWing", mesh)
    bpy.context.scene.collection.objects.link(obj)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 0.0
    sub = obj.modifiers.new("Subdivision", "SUBSURF")
    sub.levels = sub.render_levels = 1 if robo.DETAIL < 1 else 2
    for poly in mesh.polygons:
        poly.use_smooth = True
    return robo._tag(real.assign(obj, mat))


def ray(x, z, theme, p, zone):
    """A manta glider: wings swept to points over a glowing edge, gold horns forward, a ridge of
    spikes, a whip tail with a glowing blade. p: span (wing size), droop (wing curl), tail."""
    span, droop = p.get("span", 1.0), p.get("droop", 12)
    shell = theme["shell"]()
    spiked = spikes_of(zone)
    zc = z + 1.2
    edge = theme["colours"]["core"]
    wings = []
    for side in (-1, 1):
        # Each wing beats from its root by the body (finL, finR), as a pet's inner fin.
        name = "L" if side < 0 else "R"
        with robo.role("fin" + name):
            wings.append(_wing_sheet(x, zc, shell, span, droop, side))
            _wing_sheet(x, zc - 0.03, glow(edge, 4.0), span, droop, side, 1.04, 0.05)
        hinge("Fin" + name, (x + side * 0.45, 0.1, zc))
    body = sphere((x, 0.05, zc + 0.05), (0.72, 1.2, 0.36), shell, 48)
    sphere((x, 0.3, zc + 0.22), (0.38, 0.55, 0.2), theme["core"](), 32)
    gold = real.chrome("Horn", robo.GOLD, 0.25)
    for side in (-1, 1):
        spike((x + side * 0.42, -0.95, zc), 0.14, 0.75, gold, (side * 0.12, -1, 0.2))
    for dy in (-0.55, -0.15, 0.25, 0.65):
        top = zc + 0.05 + 0.36 * math.sqrt(max(0.0, 1 - ((dy - 0.05) / 1.2) ** 2))
        spike((x, dy, top - 0.04), 0.09, 0.38, spiked(theme), (0, 0.6, 1))
    scowl((x, -1.12, zc + 0.02), 0.42, 0.12, theme, -10)

    if p.get("tail", True):
        # A whip tail of shrinking beads, ending in a glowing blade: six roles from the body back
        # (tailA… tailF), so the game wags it as a wave, as a pet's.
        for step in range(16):
            r = 0.13 - 0.0055 * step
            with robo.role("tail" + "ABCDEF"[step * 6 // 16]):
                sphere((x, 1.15 + step * 0.15, zc - 0.02 * step), (r, r * 1.3, r), shell, 16)
        with robo.role("tailF"):
            sphere((x, 3.75, zc - 0.32), (0.17, 0.42, 0.03), glow(edge, 5.0), 24)
    for side in (-1, 1):
        spike((x + side * 0.05, 1.25, zc + 0.1), 0.08, 0.4, metal(), (side * 0.8, 0.6, 0.4))
    return {"shells": wings + [body], "top": (x, 0.05, zc + 0.45), "center": (x, 0.1, zc), "radius": 1.6 * span, "width": 2.6 * span,
            # As a pet's span: its wings reach about twice it.
            "span": RAY_TIP * span / 2.0, "wing_height": lambda reach: zc + _wing_height(reach, span, droop),
            "hull": ((x, 0.05, zc + 0.05), (0.72, 1.2, 0.36)), "shoulders": False, "hull_obj": body}


def stars(info, theme):
    """Gold stars along the wings' top."""
    cx = info["center"][0]
    star = real.chrome("Star", robo.GOLD, 0.25)
    span = info["span"] * 2.0 / RAY_TIP
    for side in (-1, 1):
        for reach, dy in ((1.0, -0.2), (1.6, 0.15), (2.2, 0.42)):
            reach *= span
            robo_kinds.star(cx + side * reach, dy, info["wing_height"](reach) + 0.12, 0.1, star)


# --- Whale: the leviathan -------------------------------------------------------------------------


def whale(x, z, theme, p, zone):
    """A long armoured leviathan: a flat head with an open maw full of metal teeth and a glowing
    throat, small deep-set eyes under heavy gold brows, horns swept back, a ridge of big spikes,
    clawed flippers and spiked flukes, twin thrusters. p: fins (flipper size)."""
    fins = p.get("fins", 1.0)
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
    sphere((x, -1.65, cz - 0.38), (0.62, 0.55, 0.2), real.glow("Maw", MAW, 5.0), 32)
    # Teeth: down from the skull's rim, up from the jaw's, round the front. The jaw with its
    # teeth is a role of its own (jaw), hinged at its back, so it opens wider in a chase.
    fang = metal()
    angles = [math.radians(-155 + index * (130 / 8)) for index in range(9)]
    for index, angle in enumerate(angles):
        top = on(skull, (x + math.cos(angle) * 0.85, -1.35 + math.sin(angle) * 1.0, cz - 0.3), -0.02)
        spike(top, 0.06, 0.24 if index % 2 else 0.32, fang, (0, 0, -1))
    with robo.role("jaw"):
        jaw = sphere((x, -1.2, cz - 0.55), (0.85, 1.05, 0.32), trim(), 48, (math.radians(14), 0, 0))
        for angle in angles:
            low = on(jaw, (x + math.cos(angle) * 0.72, -1.2 + math.sin(angle) * 0.9, cz - 0.3), -0.02)
            spike(low, 0.05, 0.2, fang, (0, -0.15, 1))
    hinge("Jaw", (x, -0.4, cz - 0.45))

    for side in (-1, 1):
        slit_eye(skull, (x + side * 0.6, -1.95, cz + 0.32), side, 0.16, gold)
        # Horns swept back from the brow.
        spike(on(skull, (x + side * 0.5, -1.55, cz + 0.7), -0.03), 0.13, 0.8, gold, (side * 0.55, 0.7, 0.55))
    # A gold keel down the brow.
    sphere((x, -1.45, cz + 0.72), (0.14, 0.85, 0.16), gold, 32, (math.radians(-10), 0, 0))

    # A ridge of big spikes down the back.
    for dy, length in ((-0.75, 0.55), (-0.2, 0.7), (1.6, 0.65), (2.15, 0.5), (2.6, 0.35)):
        spike(on(body, (x, dy, cz + 1.0), -0.04), 0.13, length, gold, (0, 0.45, 1))
    for side in (-1, 1):
        for dy, dz in ((-0.1, 0.4), (0.7, 0.45), (1.5, 0.35)):
            location, normal = _surface(body, (x + side * 1.1, dy, cz + dz))
            oriented(sphere(tuple(location), (0.7, 0.05, 0.08), gold, 32), normal)
        # Long flippers, angled down and swept back, glowing along the front, clawed behind; each
        # rows from its root (flipperL, flipperR).
        name = "L" if side < 0 else "R"
        with robo.role("flipper" + name):
            sweep = math.radians(side * 30)
            flipper = sphere((x + side * (0.95 + 0.45 * fins), -0.3, cz - 0.4), (0.82 * fins, 0.3 * fins, 0.06), shell, 32,
                             (0, math.radians(side * 28), sweep))
            limb((x + side * 0.9, -0.55, cz - 0.15), (x + side * (1.1 + 0.9 * fins), 0.05, cz - 0.15 - 0.57 * fins), 0.03, glow(accent, 8.0))
            # Claws on the trailing edge, on its outer half (the flipper's own frame: its local +Y
            # is its back edge; the outer end is whichever end of local X lies further out).
            bpy.context.view_layer.update()
            frame = flipper.matrix_world
            outer = 1 if (frame @ Vector((1, 0, 0))).x * side > (frame @ Vector((-1, 0, 0))).x * side else -1
            back = (frame.to_3x3() @ Vector((0, 1, 0))).normalized()
            for u in (0.3, 0.55, 0.8):
                spike(frame @ Vector((outer * u, math.sqrt(1 - u * u) * 0.9, 0)), 0.05, 0.28, fang, back + Vector((side * 0.3, 0, 0)))
        hinge("Flipper" + name, (x + side * 0.9, -0.35, cz - 0.3))
        # The flukes with spiked tips beat together (one role, flukes).
        with robo.role("flukes"):
            sphere((x + side * 0.85, 3.25, cz + 0.15), (1.0, 0.34, 0.06), shell, 32, (0, 0, math.radians(side * 34)))
            spike((x + side * 1.6, 3.7, cz + 0.15), 0.07, 0.4, gold, (side * 0.85, 0.6, 0))
        # Twin thrusters under the tail stock fire down: two round glows facing back would read
        # as a second pair of eyes from behind (BLENDER_ROBLOX.md, section 2).
        cylinder((x + side * 0.38, 2.45, cz - 0.45), 0.16, 0.36, real.gloss("Engine", (0.1, 0.11, 0.13), 0.3))
        sphere((x + side * 0.38, 2.45, cz - 0.64), (0.12, 0.12, 0.04), glow(accent, 12.0), 24)
    hinge("Flukes", (x, 2.95, cz + 0.15))
    sphere((x, 2.75, cz + 0.12), (0.38, 0.65, 0.3), shell, 32)
    return {"shells": [body, skull], "top": (x, -0.6, cz + 1.0), "center": (x, 0.5, cz), "radius": 1.2, "width": 1.5, "size": 1.2,
            "hull": ((x, 0.5, cz), (1.0, 2.3, 0.85)), "hull_obj": body}


def galaxy(info, theme):
    """A nebula window down the back and stars over it."""
    body = info["hull_obj"]
    cx, cy, cz = info["center"]
    sphere(on(body, (cx, cy + 0.2, cz + 1.0), -0.12), (0.38, 0.95, 0.18), theme["core"](), 32)
    star = real.glow("BackStar", (1.0, 0.95, 0.85), 12.0)
    for index in range(8):
        angle = index * 2.4
        sphere(on(body, (cx + math.cos(angle) * 0.65, cy + 0.2 + math.sin(angle) * 1.3, cz + 0.8), 0.01), (0.03,) * 3, star, 10)


# --- Building -------------------------------------------------------------------------------------


# family: (builder, pet_scale: how much bigger than its pet the adult's body is, growth: to guardian
# size in the concept sheets).
FAMILIES = {
    "slime": (slime, 1.2, 2.2),
    "crab": (crab, 1.3, 2.0),
    "worm": (worm, 1.2, 2.0),
    "swarm": (swarm, 1.25, 1.9),
    "ray": (ray, 1.4, 2.0),
    "whale": (whale, 1.3, 1.8),
}

# A pet signature's adult version, drawn on the full-size adult instead of the pet's.
ADULT_SIGNATURES = {"siren": siren, "rotor": rotors, "stars": stars, "galaxy": galaxy, "mandibles": no_mandibles}
# Pet signatures with an adult version drawn at the pet's size.
PET_SIZE_OVERRIDES = {"queen": queen}

POINT_KEYS = ("top", "center", "head", "lead", "flank")
LENGTH_KEYS = ("radius", "width", "head_r", "lead_size", "span", "size", "flank_r")


def _scaled(info, x, z, factor):
    """The anchors of an adult whose parts were scaled by `factor` about its base point."""
    base = Vector((x, 0, z))

    def point(p):
        return tuple(base + (Vector(p) - base) * factor)

    out = {key: value for key, value in info.items() if not key.startswith("_")}
    for key in POINT_KEYS:
        if key in out:
            out[key] = point(out[key])
    for key in LENGTH_KEYS:
        if key in out:
            out[key] = out[key] * factor
    if "hull" in out:
        centre, radii = out["hull"]
        out["hull"] = (point(centre), tuple(r * factor for r in radii))
    if "wing_height" in out:
        height = info["wing_height"]
        out["wing_height"] = lambda reach: z + (height(reach / factor) - z) * factor
    return out


def kind_of(kind_id):
    return next(k for k in robo_kinds.KINDS if k[0] == kind_id)


def build(kind, x, z, growth=None):
    """The adult guardian of a post, from its main kind: the family's adult in the kind's colours,
    shape and signature parts, grown to guardian size."""
    _, _, family, zone, look, shape, signature = kind[:7]
    make, pet_scale, default_growth = FAMILIES[family]
    paint = robo.theme(zone, look)
    before = set(bpy.data.objects)
    info = make(x, z, paint, shape or {}, zone)
    info["tier"] = 2
    for part in signature:
        if part.__name__ in ADULT_SIGNATURES:
            ADULT_SIGNATURES[part.__name__](info, paint)
    # The pets' own signature parts, on the adult shrunk to a pet's size.
    robo._grow(set(bpy.data.objects) - before, x, z, 1 / pet_scale)
    small = _scaled(info, x, z, 1 / pet_scale)
    for part in signature:
        if part.__name__ not in ADULT_SIGNATURES:
            PET_SIZE_OVERRIDES.get(part.__name__, part)(small, paint)
    # Small parts on a moving part (a star on a fin, an icicle on a segment) move with it.
    robo._carry_riders(set(bpy.data.objects) - before, small)
    robo._grow(set(bpy.data.objects) - before, x, z, pet_scale * (growth if growth is not None else default_growth))
    return info
