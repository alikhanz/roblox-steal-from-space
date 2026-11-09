# The 72 alien kinds as robot pets (decisions 074, 075): three per guardian post, in the post
# order of GuardianConfig.POSTS (six posts per zone). The main kind is the guardian's baby, in its
# family; the second and the rare kind come from other families but wear the guardian's colours
# and its signature part, so every zone holds all six forms and every kind still belongs to its
# guardian. A kind differs from its zone-mates in silhouette (the family's shape parameters) and a
# signature part a child can name ("the one with the propeller"), not by colour alone.

import math

import real
import robo
from mathutils import Euler, Vector
from robo import cone, cylinder, gem, glow, pill, sphere, torus

WHITE = (0.97, 0.98, 1.0)
SLOTS = ["Основной", "Второй", "Редкий"]


def _lead(info):
    """The body a part sits on: a swarm's lead drone, a worm's head (its body centre sits back
    towards the tail), or the whole pet."""
    if "lead" in info:
        return info["lead"], info["lead_size"]
    if "head" in info:
        return info["head"], info["head_r"] / 0.58
    return info["center"], info["radius"] / 0.8


# --- Signature parts ------------------------------------------------------------------------------


def siren(info, theme):
    """A warden's light bar: red and blue lamps on top, and a gold badge."""
    tx, ty, height = robo._crown_spot(info)
    big = info.get("hull", (None, (1.0,)))[1][0] > 0.7
    # On top; on a small head (a lead drone, a ray) the crown needs the top, so at the crown's
    # tier the bar moves to the back of the head.
    back = 0.0 if big or info.get("tier", 0) < 4 else (0.4 if "span" in info else 0.5)
    by = ty + back
    tz = height(tx, by)
    pill((tx, by, tz + 0.03), (0.3, 0.1, 0.06), real.gloss("Bar", (0.12, 0.13, 0.15), 0.3))
    for side, colour in ((-1, (1.0, 0.15, 0.15)), (1, (0.2, 0.45, 1.0))):
        sphere((tx + side * 0.16, by, tz + 0.13), (0.11, 0.09, 0.09), real.glow("Siren", colour, 12.0), 16)
    # On a big head the crown goes round the bar. The antenna stands behind it.
    if big:
        info["crown_r"] = 0.44
    info["beacon_at"] = (0.0, 0.32)
    (cx, cy, cz), r, snap = robo._flank(info)
    # The badge low on the front; off to one side on a ray, whose visor fills its narrow front.
    side = 0.35 * r if "span" in info else 0.0
    pill(snap((cx + side, cy - r * 0.86, cz - 0.45 * r), 0.02), (0.16, 0.04, 0.12), real.chrome("Badge", robo.GOLD, 0.25))


def rotor(info, theme):
    """A drone's propeller on a mast, high enough to spin over the antenna and the crown."""
    tx, ty, height = robo._crown_spot(info)
    tz = height(tx, ty)
    cylinder((tx, ty, tz + 0.28), 0.04, 0.7, real.gloss("Mast", (0.15, 0.16, 0.18), 0.3))
    with robo.role("rotor"):
        blade = real.gloss("Blade", (0.92, 0.93, 0.96), 0.2)
        for spin in (20, 110):
            b = pill((tx, ty, tz + 0.62), (0.7, 0.07, 0.02), blade)
            b.rotation_euler = (math.radians(4), 0, math.radians(spin))
        sphere((tx, ty, tz + 0.64), (0.09, 0.09, 0.06), glow(theme["accent"], 10.0), 16)


@robo.in_role("fx")
def bubbles(info, theme):
    """Acid bubbling up, and a hazard-striped belt."""
    tx, ty, tz = info["top"]
    mat = real.crystal("Bubble", theme["colours"]["core"], 2.0)
    for dx, dy, dz, size in ((-0.15, 0.0, 0.15, 0.1), (0.18, -0.05, 0.38, 0.08), (-0.05, 0.05, 0.6, 0.06), (0.12, 0.0, 0.82, 0.045)):
        sphere((tx + dx, ty + dy, tz + dz), (size,) * 3, mat, 20)
    cx, cy, cz = info["center"]
    r = min(info["radius"] * 0.62, 0.7)
    stripe = real.gloss("Hazard", (0.08, 0.08, 0.09), 0.25)
    yellow = real.gloss("Yellow", (1.0, 0.8, 0.1), 0.2)
    for index in range(8):
        angle = index / 8 * math.tau
        pill((cx + math.cos(angle) * r, cy + math.sin(angle) * r, cz - 0.45), (0.1, 0.05, 0.05), stripe if index % 2 else yellow, (0, 0, angle + math.pi / 2))


def exhausts(info, theme):
    """A tank's exhaust pipes and rivets."""
    (cx, cy, cz), r, snap = robo._flank(info)
    pipe = real.chrome("Pipe", (0.45, 0.42, 0.4), 0.35)
    for side in (-1, 1):
        # The pipe's foot on the back, close to the spine: behind the crown, above the thrusters,
        # clear of a lead drone's little wings.
        fx, fy, fz = snap((cx + side * 0.22, cy + r * 0.6, cz + r * 0.35))
        cylinder((fx, fy, fz + 0.35), 0.09, 0.7, pipe, (math.radians(-15), 0, 0))
        sphere((fx, fy + 0.08, fz + 0.72), (0.07, 0.07, 0.03), glow((1.0, 0.45, 0.1), 8.0), 12)
    rivet = real.chrome("Rivet", (0.3, 0.28, 0.27), 0.3)
    # A row over the brow, above the visor.
    for dx in (-0.6, -0.36, -0.12, 0.12, 0.36, 0.6):
        sphere(snap((cx + dx * r, cy - r * 0.68, cz + 0.5 * r)), (0.045, 0.03, 0.045), rivet, 12)


def circlet(info, theme):
    """A royal band with a jewel, round the top of the head."""
    tx, ty, height = robo._crown_spot(info)
    a = info["hull"][1][0] if "hull" in info else 0.75
    # Snug on the head: narrower on a small head, so it stays above a drone's little wings.
    band = min(0.45, a * 0.5)
    tz = min(height(tx + math.cos(t) * band, ty + math.sin(t) * band) for t in (0, math.pi / 2, math.pi, 1.5 * math.pi)) + 0.02
    gold = real.chrome("Circlet", robo.GOLD, 0.22)
    torus((tx, ty, tz), band, 0.06, gold)
    # The jewel hangs on the band's front, below the crown that rests on the band.
    sphere((tx, ty - band, tz - 0.04), (0.1, 0.06, 0.1), real.glow("Jewel", (0.4, 0.8, 1.0), 10.0), 16)
    # At the crown's tier the crown rests on the band.
    info["crown_r"] = band
    info["crown_lift"] = 0.1
    (cx, cy, cz), r, snap = robo._flank(info)
    for side in (-1, 1):
        # Gold studs low on the flanks, under the side lights and the emblem (the shoulder plates
        # take the space above).
        sphere(snap((cx + side * r * 0.85, cy - 0.35, cz - 0.4)), (0.2, 0.18, 0.07), gold, 24)


def pincers(info, theme):
    """Two little claws held up in front: under the chin of a pet with a head (a worm, whose body
    centre sits back towards its tail), at the front of the body otherwise."""
    shell = theme["accent_shell"]()
    if "head" in info:
        hx, hy, hz = info["head"]
        r = info["head_r"]
        # Low under the chin, below the emblems on the cheeks.
        snap = robo._flank(info)[2]
        bases = [Vector(snap((hx + side * r * 0.6, hy - r * 0.6, hz - r * 0.9))) for side in (-1, 1)]
    else:
        (lx, ly, lz), size = _lead(info)
        # Held at the front of the body, rooted in it.
        hull = [info["hull_obj"]] if "hull_obj" in info else None
        # Wide and low, clear of the visor.
        bases = [Vector(robo.stick(info, (lx + side * 0.55 * size, ly - 0.55 * size, lz - 0.25), 0.0, hull)) for side in (-1, 1)]
    for side, base in zip((-1, 1), bases):
        sphere(tuple(base), (0.16, 0.2, 0.14), shell, 24)
        # The two jaws snap like a crab's: the same roles (jawTopL…) on a hinge at their root.
        name = "L" if side < 0 else "R"
        with robo.role("jawTop" + name):
            pill(tuple(base + Vector((side * 0.05, -0.2, 0.08))), (0.06, 0.13, 0.04), shell, (math.radians(-20), 0, 0))
        with robo.role("jawBot" + name):
            pill(tuple(base + Vector((0, -0.18, -0.07))), (0.05, 0.11, 0.035), shell, (math.radians(20), 0, 0))
        with robo.role("hingeJaw" + name):
            sphere(tuple(base + Vector((0, -0.08, 0))), (0.02, 0.02, 0.02), shell, 8)


def icicles(info, theme):
    """Icicles hanging from the belly."""
    (cx, cy, cz), r, snap = robo._flank(info)
    ice = real.crystal("Icicle", (0.75, 0.95, 1.0), 1.5)
    for index in range(5):
        # Rooted in the underside, a little sunk.
        base = snap((cx - r * 0.5 + index * r * 0.25, cy - 0.1, cz - r), -0.02)
        cone(base, 0.06, 0.22 + 0.05 * (index % 2), ice, (0, 0, -1))


def snowcap(info, theme):
    """A fluffy snow cap and a snowflake badge."""
    tx, ty, height = robo._crown_spot(info)
    tz = height(tx, ty - 0.1) - 0.05
    snow = real.frost("Snow", WHITE, 0.6)
    sphere((tx, ty - 0.1, tz), (0.62, 0.5, 0.2), snow, 32)
    for dx, dz in ((-0.42, -0.05), (0.38, -0.07), (0.0, 0.05)):
        sphere((tx + dx, ty - 0.2, tz + dz), (0.18, 0.18, 0.14), snow, 20)
    # The crown sits on the snow; the antenna stands behind the cap.
    info["crown_lift"] = 0.22
    info["beacon_at"] = (-0.4, 0.5)
    # Ice shards on the back keep clear of the cap.
    info["crowded_top"] = True
    (cx, cy, cz), r, snap = robo._flank(info)
    # The snowflake badge low on the front, off to one side: clear of the face.
    flake(*snap((cx + r * 0.35, cy - r, cz - 0.45 * r), 0.02), 0.13)


def flake(x, y, z, size):
    mat = real.glow("Flake", (0.7, 0.95, 1.0), 8.0)
    for spin in range(3):
        pill((x, y, z), (size, 0.02, 0.018), mat, (0, math.radians(spin * 60), 0))


@robo.in_role("fx")
def flakes(info, theme):
    """Snowflakes drifting round the pet."""
    cx, cy, cz = info["center"]
    r = info["radius"] + 0.3
    for index in range(6):
        angle = index / 6 * math.tau + 0.4
        flake(cx + math.cos(angle) * r, cy - 0.4, cz + 0.2 + 0.45 * math.sin(index * 2.1), 0.1 + 0.03 * (index % 2))


def ice_crown(info, theme):
    """A ring of ice spikes on top, wide enough for the crown to sit inside it."""
    tx, ty, height = robo._crown_spot(info)
    # Inside the head's edge on a flat ray, where the side lights sit.
    ring = min(0.52, info["hull"][1][0] * 0.6) if "hull" in info else 0.52
    if ring < 0.52:
        # A smaller crown inside a smaller ring.
        info["crown_r"] = max(0.22, ring - 0.2)
    # Ice shards on the back keep clear of the ring.
    info["crowded_top"] = True
    ice = real.crystal("IceSpike", (0.75, 0.95, 1.0), 2.0)
    for index in range(9):
        angle = index / 9 * math.tau
        out = Vector((math.cos(angle) * 0.35, math.sin(angle) * 0.35, 1.0))
        x, y = tx + math.cos(angle) * ring, ty + math.sin(angle) * ring
        cone((x, y, height(x, y) - 0.03), 0.08, 0.32 + 0.12 * (index % 2), ice, tuple(out))


def ice_fringe(info, theme):
    """Icicles along the trailing edges (a ray's wings, or round the body)."""
    cx, cy, cz = info["center"]
    span = info.get("span", 0.55)
    ice = real.crystal("Fringe", (0.75, 0.95, 1.0), 1.5)
    for side in (-1, 1):
        for index in range(4):
            reach = 0.5 + index * 0.38
            # Hanging from the wing's (or body's) edge, rooted in it.
            base = robo.stick(info, (cx + side * reach * span, cy + 0.6 + index * 0.06, cz + 0.05 + index * 0.08), -0.01)
            cone(base, 0.05, 0.2, ice, (0, 0.4, -1))


def plow(info, theme):
    """An icebreaker's wedge on the nose."""
    cx, cy, cz = info["center"]
    r = info["radius"]
    steel = real.chrome("Plow", (0.75, 0.85, 0.95), 0.2)
    for side in (-1, 1):
        pill((cx + side * 0.35 * r, cy - r * 0.95, cz - 0.15), (0.45 * r, 0.06, 0.28), steel, (0, 0, math.radians(side * 35)))
    cone((cx, cy - r * 1.15, cz - 0.15), 0.12, 0.3, steel, (0, -1, 0))


def aurora(info, theme):
    """Northern lights rippling over the pet."""
    cx, cy, cz = info["center"]
    r = info["radius"]
    for band, colour in enumerate(((0.3, 1.0, 0.6), (0.5, 0.6, 1.0), (0.8, 0.4, 1.0))):
        for step in range(7):
            t = step / 6 - 0.5
            pill((cx + t * 2.2 * r, cy + 0.3 + band * 0.18, cz + r + 0.4 + band * 0.12 + 0.12 * math.sin(step * 1.3 + band)),
                 (0.17 * r, 0.015, 0.16), real.glow("Aurora", colour, 5.0), (0, math.radians(15 * math.sin(step + band)), 0))


def frill(info, theme):
    """A fan collar round the head (a mother's frill)."""
    if "head" in info:
        hx, hy, hz = info["head"]
        r = info["head_r"]
    else:
        hx, hy, hz = info["center"]
        r = info["radius"] * 0.7
    snap = robo._flank(info)[2]
    fan = real.iridescent("Frill", theme["colours"]["trim"], transmission=0.5, glow=1.5)
    for index in range(7):
        angle = math.radians(-70 + index * 23)
        out = Vector((math.sin(angle), 0.35, math.cos(angle)))
        # Each petal rooted in the hull, fanning out from it.
        root = Vector(snap(tuple(Vector((hx, hy + 0.25, hz)) + out * r)))
        f = sphere(tuple(root + out.normalized() * 0.22), (0.14, 0.04, 0.32), fan, 24)
        f.rotation_euler = out.to_track_quat("Z", "Y").to_euler()


def babies(info, theme):
    """A mother worm's frill and two little worms beside her."""
    frill(info, theme)
    hx, hy, hz = info.get("head", info["center"])
    shell = theme["shell"]()
    for side in (-1, 1):
        bx = hx + side * 1.15
        for step in range(3):
            sphere((bx + side * step * 0.05, -0.2 + step * 0.17, hz - 0.95 + (0.2 if step == 0 else 0.12 - 0.04 * step)), (0.17 - 0.03 * step,) * 3, shell, 24)
        robo.visor((bx, -0.37, hz - 0.72), 0.12, 0.05, theme["eyes"])


def mandibles(info, theme):
    """Curved jaws in front (on each drone of a swarm)."""
    (lx, ly, lz), size = _lead(info)
    jaw = real.chrome("Jaw", (0.85, 0.85, 0.9), 0.2)
    for side in (-1, 1):
        # Each jaw is a role of its own (mandL, mandR) on a hinge at its root: the game opens and
        # closes them like a beetle's.
        name = "L" if side < 0 else "R"
        root = (lx + side * 0.22 * size, ly - 0.42 * size, lz - 0.2 * size)
        with robo.role("mand" + name):
            cone(root, 0.07 * size, 0.42 * size, jaw, (-side * 0.6, -1, -0.3))
        with robo.role("hingeMand" + name):
            sphere(root, (0.02, 0.02, 0.02), jaw, 8)
    for index, (location, s) in enumerate(info.get("drones", [])):
        # A little drone's jaws fly with it and snap too: roles drone1MandL… (the drone's own
        # number first, so the game flies them with it), each on a hinge at its root.
        for side in (-1, 1):
            name = f"drone{index + 1}Mand" + ("L" if side < 0 else "R")
            root = (location.x + side * 0.1 * s, location.y - 0.4 * s, location.z - 0.15 * s)
            with robo.role(name):
                cone(root, 0.04 * s, 0.22 * s, jaw, (-side * 0.6, -1, -0.3))
            with robo.role("hinge" + name[0].upper() + name[1:]):
                sphere(root, (0.015, 0.015, 0.015), jaw, 8)


def crest(info, theme):
    """A crest of spines down the back of the head (behind the crown's place)."""
    (lx, ly, lz), size = _lead(info)
    tx, ty, height = robo._crown_spot(info)
    spine = theme["accent_shell"]()
    for index in range(5):
        angle = math.radians(-40 + index * 20)
        x, y = lx + math.sin(angle) * 0.3 * size, ty + 0.35 * size
        cone((x, y, height(x, y) - 0.04), 0.07, 0.35 + 0.15 * (index == 2), spine, (math.sin(angle) * 0.6, 0.3, 1))


def queen(info, theme):
    """A queen's jaws, crest and glowing brood pods under her."""
    mandibles(info, theme)
    crest(info, theme)
    (lx, ly, lz), size = _lead(info)
    snap = robo._flank(info)[2]
    pod = real.jelly("Brood", theme["colours"]["core"], glow=3.0, clear=True)
    for dx, dy in ((-0.35, 0.1), (0.0, 0.25), (0.35, 0.1)):
        # Hanging from her belly, half in it.
        sphere(snap((lx + dx * size, ly + dy, lz - 0.75 * size), 0.06), (0.14, 0.14, 0.18), pod, 20)


def guard(info, theme):
    """A royal guard: jaws and a crest."""
    mandibles(info, theme)
    crest(info, theme)


def star(x, y, z, size, mat):
    for index in range(5):
        angle = index / 5 * math.tau + math.pi / 2
        spike = cone((x, y, z), size * 0.45, size * 1.4, mat, (math.cos(angle), 0, math.sin(angle)))
        spike.rotation_euler.rotate_axis("X", math.radians(90))
    sphere((x, y, z), (size * 0.5,) * 3, mat, 12)


def stars(info, theme):
    """Gold stars: along the wings of a ray, scattered over the back of anything else."""
    cx, cy, cz = info["center"]
    gold = real.glow("Star", robo.GOLD, 8.0)
    if "span" in info:
        span = info["span"]
        for side in (-1, 1):
            for reach, dz in ((0.7, 0.08), (1.25, 0.2), (1.7, 0.33)):
                # On the wing's top, a little out of it.
                star(*robo.stick(info, (cx + side * reach * span, cy + 0.25 + reach * 0.12, cz + dz + 0.06), 0.03), 0.08, gold)
        return
    (cx, cy, cz), r, snap = robo._flank(info)
    for index in range(5):
        angle = index / 5 * math.tau + 0.3
        star(*snap((cx + math.cos(angle) * r * 0.7, cy - r * 0.6, cz + 0.2 + math.sin(angle) * r * 0.45), 0.02), 0.09, gold)
    # A big star on top; at the crown's tier the crown takes the top.
    if info.get("tier", 0) < 4:
        tx, ty, height = robo._crown_spot(info)
        star(tx, ty, height(tx, ty) + 0.12, 0.14, gold)
        info["beacon_at"] = (0.0, 0.32)


@robo.in_role("flame")
def flames(info, theme):
    """Flames licking up from the top, like a candle."""
    tx, ty, tz = info["top"]
    for dx, height, colour in ((0.0, 0.85, (1.0, 0.55, 0.1)), (-0.22, 0.55, (1.0, 0.3, 0.08)), (0.24, 0.6, (1.0, 0.3, 0.08))):
        cone((tx + dx, ty, tz - 0.25), 0.18, height, real.glow("Flame", colour, 4.0), (dx * 0.6, 0, 1))
        cone((tx + dx, ty - 0.02, tz - 0.22), 0.09, height * 0.65, real.glow("FlameCore", (1.0, 0.85, 0.35), 6.0), (dx * 0.6, 0, 1))


def _bolt(points, mat):
    for a, b in zip(points, points[1:]):
        start, end = Vector(a), Vector(b)
        seg = cylinder(tuple((start + end) / 2), 0.035, (end - start).length, mat)
        seg.rotation_euler = (end - start).to_track_quat("Z", "Y").to_euler()


def lightning(info, theme):
    """Zigzag bolts along the wings of a ray, or crackling over anything else."""
    cx, cy, cz = info["center"]
    bolt = real.glow("Bolt", (1.0, 0.9, 0.3), 10.0)
    if "span" in info:
        span = info["span"]
        for side in (-1, 1):
            zig = [(0.45, 0.0), (0.85, 0.22), (1.15, 0.05), (1.55, 0.3), (1.9, 0.12)]
            # Crackling along the wing's top, each kink on it.
            _bolt([robo.stick(info, (cx + side * a * span, cy + 0.2, cz + 0.12 + z), 0.03) for a, z in zig], bolt)
        return
    # Two bolts leaping up off the sides of the head, clear of the crown (a third one down a flank
    # had no room among the lights, plates and thrusters).
    tx, ty, height = robo._crown_spot(info)
    for side in (-1, 1):
        x0 = tx + side * 0.42
        z0 = height(x0, ty) - 0.03
        _bolt([(x0, ty, z0), (x0 + side * 0.25, ty, z0 + 0.3), (x0 + side * 0.13, ty, z0 + 0.45), (x0 + side * 0.4, ty, z0 + 0.8)], bolt)


def minions(info, theme):
    """Three tiny drones buzzing round the pet: each a role of its own (drone1…), so the game
    flies them round it like a swarm's little drones."""
    cx, cy, cz = info["center"]
    r = info["radius"] + 0.35
    shell = theme["shell"]()
    for index in range(3):
        angle = index / 3 * math.tau + 0.9
        with robo.role(f"drone{index + 1}"):
            robo.drone(cx + math.cos(angle) * r, cy + math.sin(angle) * r * 0.5 - 0.2, cz + 0.4 + 0.3 * index, 0.3, theme, shell,
                       buzz=f"drone{index + 1}Buzz")


def void_core(info, theme):
    """A tiny black hole over the pet: a dark sphere in a burning ring."""
    (lx, ly, lz), size = _lead(info)
    # Hovering over the head, high enough to clear the antenna and the crown.
    height = robo._crown_spot(info)[2]
    where = (lx, ly + 0.2, height(lx, ly + 0.2) + 0.95)
    sphere(where, (0.22,) * 3, real.gloss("Void", (0.0, 0.0, 0.0), 0.05), 32)
    torus(where, 0.36, 0.05, real.glow("Horizon", (1.0, 0.6, 0.95), 8.0), (math.radians(70), 0, 0))
    torus(where, 0.5, 0.015, real.glow("HorizonOuter", (0.6, 0.5, 1.0), 6.0), (math.radians(70), 0, 0))


def dots(info, theme):
    """Glowing dots over the body, like stars in the dark."""
    (cx, cy, cz), r, snap = robo._flank(info)
    mat = real.glow("Dot", theme["accent"], 10.0)
    for index in range(9):
        # Over the back half, clear of the face.
        sphere(snap((cx - 0.25 * r + index * 0.0625 * r + 0.05 * math.sin(index), cy + 0.5 * r, cz + 0.6 * r + 0.1 * math.cos(index * 2))), (0.04,) * 3, mat, 10)


def smoke(info, theme):
    """Glowing dots and a wisp of shadow behind."""
    dots(info, theme)
    cx, cy, cz = info["center"]
    with robo.role("fx"):
        for index in range(4):
            sphere((cx + 0.3 + 0.15 * index, cy + 0.9 + index * 0.35, cz - 0.1 + 0.1 * index), (0.22 + 0.06 * index,) * 3, real.aura("Smoke", (0.35, 0.2, 0.6), 0.8, 0.08), 20)


def star_dots(info, theme):
    """Violet star dots over the wings or the back."""
    cx, cy, cz = info["center"]
    span = info.get("span", info["radius"] * 0.5)
    mat = real.glow("StarDot", theme["accent"], 12.0)
    for side in (-1, 1):
        for reach, dy in ((0.5, 0.0), (0.9, 0.25), (1.3, 0.1), (1.65, 0.4), (1.1, 0.5)):
            # Studs on the wing or the back, half in it.
            sphere(robo.stick(info, (cx + side * reach * span, cy + 0.15 + dy - 0.5, cz + 0.12 + reach * 0.12)), (0.035,) * 3, mat, 10)


def gravity(info, theme):
    """Rocks held in orbit and glowing anti-gravity pads beneath."""
    cx, cy, cz = info["center"]
    r = info["radius"]
    rock = real.armor("Rock", (0.35, 0.33, 0.38))
    for index in range(4):
        angle = index / 4 * math.tau + 0.4
        gem((cx + math.cos(angle) * (r + 0.2), cy + math.sin(angle) * 0.9, cz + 0.75 + 0.15 * math.sin(index * 2)), (0.16, 0.13, 0.12), rock, (index, index * 0.5, 0))
    pad = real.glow("Pad", theme["accent"], 6.0)
    base = info["top"][2] - (info["top"][2] - cz) * 2 - 0.05
    torus((cx, cy, max(base, cz - 1.2)), r + 0.25, 0.03, pad)


@robo.in_role("fx")
def spout(info, theme):
    """A spout of glowing bubbles."""
    tx, ty, tz = info["top"]
    mat = real.crystal("Spout", (0.7, 0.9, 1.0), 3.0)
    for dx, dz, size in ((0.0, 0.0, 0.1), (-0.12, 0.2, 0.08), (0.14, 0.32, 0.075), (-0.05, 0.48, 0.06), (0.1, 0.62, 0.05), (-0.15, 0.7, 0.045)):
        sphere((tx + dx, ty - 0.1, tz + dz), (size,) * 3, mat, 16)


def telescope(info, theme):
    """A stargazer's brass telescope pointed at the sky, standing on its back (clear of the crown)."""
    tx, ty, height = robo._crown_spot(info)
    brass = real.chrome("Brass", (0.85, 0.62, 0.3), 0.25)
    turn = Euler((math.radians(-35), math.radians(25), 0)).to_matrix()
    axis = turn @ Vector((0, 0, 1))
    # The tube's lower end rests on the hull, a little sunk.
    fx, fy = tx + 0.3, ty + 0.4
    foot = Vector((fx, fy, height(fx, fy) - 0.03))
    centre = foot + axis * 0.35
    cylinder(tuple(centre), 0.09, 0.7, brass, (math.radians(-35), math.radians(25), 0))
    sphere(tuple(foot + axis * 0.72), (0.1, 0.1, 0.1), real.glow("Lens", (0.6, 0.85, 1.0), 6.0), 16)


def galaxy(info, theme):
    """A galaxy across the body and star dots over it."""
    (cx, cy, cz), r, snap = robo._flank(info)
    s = info.get("size", r / 1.2)
    # A belly patch, kept below and behind the face.
    sphere((cx, cy - 0.2 * s, cz - 0.28 * s), (0.78 * s, 0.7 * s, 0.5 * s), real.nebula("Galaxy", (0.05, 0.02, 0.15), (0.6, 0.3, 0.9), (1.0, 0.9, 0.95), 10.0), 48)
    mat = real.glow("BackStar", (1.0, 0.95, 0.85), 12.0)
    for index in range(10):
        angle = index * 2.4
        # Over the back, behind the crown's place.
        sphere(snap((cx + math.cos(angle) * 0.45 * s, cy + 0.5 * s + math.sin(angle) * 0.15 * s, cz + 0.5 * s)), (0.03,) * 3, mat, 10)


# --- The posts and their kinds ---------------------------------------------------------------------
# Each guardian has a palette of its own, bold enough to tell it from its zone-mates at a glance
# (linear colours: body, trim, glow, eyes, core). Its three kinds share it: the main kind wears it
# as is, the second kind swaps body and trim, the rare kind wears the body colour as candy metal.
PALETTE = {
    # Debris Belt
    "Слизень-сторож": {"shell": (0.04, 0.12, 0.5), "trim": (0.9, 0.92, 0.95), "glow": (0.3, 0.6, 1.0), "eyes": (0.4, 0.9, 1.0), "core": (0.2, 0.9, 0.25)},
    "Краб-дрон": {"shell": (0.95, 0.6, 0.02), "trim": (0.08, 0.08, 0.1), "glow": (1.0, 0.75, 0.1), "eyes": (0.3, 0.9, 1.0), "core": (1.0, 0.6, 0.05)},
    "Лиловый краб": {"shell": (0.35, 0.07, 0.75), "trim": (1.0, 0.45, 0.75), "glow": (0.85, 0.45, 1.0), "eyes": (1.0, 0.6, 0.9), "core": (0.8, 0.3, 1.0)},
    "Кислотный слизень": {"shell": (0.08, 0.08, 0.1), "trim": (0.45, 0.85, 0.02), "glow": (0.6, 1.0, 0.1), "eyes": (0.6, 1.0, 0.2), "core": (0.55, 1.0, 0.05)},
    "Ржавый краб": {"shell": (0.7, 0.17, 0.03), "trim": (0.25, 0.1, 0.05), "glow": (1.0, 0.5, 0.1), "eyes": (1.0, 0.8, 0.3), "core": (1.0, 0.4, 0.05)},
    "Король слизней": {"shell": (0.6, 0.02, 0.06), "trim": (1.0, 0.7, 0.15), "glow": (1.0, 0.75, 0.25), "eyes": (1.0, 0.9, 0.5), "core": (0.7, 0.25, 1.0)},
    # Ice Rings
    "Ледяной червь": {"shell": (0.1, 0.55, 0.9), "trim": (0.9, 0.97, 1.0), "glow": (0.4, 0.9, 1.0), "eyes": (0.6, 1.0, 1.0), "core": (0.4, 0.9, 1.0)},
    "Снежный краб": {"shell": (0.92, 0.95, 1.0), "trim": (0.75, 0.04, 0.08), "glow": (1.0, 0.3, 0.3), "eyes": (0.4, 0.8, 1.0), "core": (1.0, 0.35, 0.3)},
    "Морозный слизень": {"shell": (0.02, 0.55, 0.45), "trim": (0.85, 1.0, 0.97), "glow": (0.4, 1.0, 0.85), "eyes": (0.6, 1.0, 0.9), "core": (0.7, 1.0, 0.95)},
    "Хрустальный червь": {"shell": (0.85, 0.95, 1.0), "trim": (0.6, 0.85, 1.0), "glow": (0.8, 0.6, 1.0), "eyes": (0.9, 0.8, 1.0), "core": (0.85, 0.6, 1.0), "finish": "glass"},
    "Ледяной скат": {"shell": (0.02, 0.12, 0.6), "trim": (0.85, 0.95, 1.0), "glow": (0.3, 0.8, 1.0), "eyes": (0.5, 0.95, 1.0), "core": (0.3, 0.75, 1.0)},
    "Мать червей": {"shell": (0.8, 0.35, 0.75), "trim": (0.95, 0.9, 1.0), "glow": (1.0, 0.55, 0.9), "eyes": (1.0, 0.75, 0.95), "core": (1.0, 0.5, 0.85)},
    # Red Nebula
    "Рой пожирателей": {"shell": (0.85, 0.02, 0.35), "trim": (0.08, 0.06, 0.08), "glow": (1.0, 0.3, 0.6), "eyes": (1.0, 0.85, 0.3), "core": (1.0, 0.2, 0.5)},
    "Звёздный скат": {"shell": (0.03, 0.06, 0.5), "trim": (1.0, 0.72, 0.15), "glow": (1.0, 0.8, 0.3), "eyes": (1.0, 0.9, 0.5), "core": (0.4, 0.45, 1.0)},
    "Огненный слизень": {"shell": (0.95, 0.25, 0.02), "trim": (1.0, 0.85, 0.2), "glow": (1.0, 0.55, 0.1), "eyes": (1.0, 0.95, 0.5), "core": (1.0, 0.45, 0.05)},
    "Красный рой": {"shell": (0.65, 0.01, 0.02), "trim": (0.95, 0.9, 0.88), "glow": (1.0, 0.25, 0.2), "eyes": (1.0, 0.8, 0.4), "core": (1.0, 0.2, 0.15)},
    "Скат-молния": {"shell": (1.0, 0.8, 0.05), "trim": (0.05, 0.08, 0.3), "glow": (1.0, 0.95, 0.4), "eyes": (0.5, 0.85, 1.0), "core": (0.4, 0.7, 1.0)},
    "Матка пожирателей": {"shell": (0.3, 0.02, 0.2), "trim": (1.0, 0.7, 0.15), "glow": (1.0, 0.4, 0.75), "eyes": (1.0, 0.85, 0.3), "core": (1.0, 0.35, 0.7)},
    # Event Horizon
    "Теневой червь": {"shell": (0.06, 0.02, 0.12), "trim": (0.35, 0.1, 0.6), "glow": (0.75, 0.4, 1.0), "eyes": (0.85, 0.6, 1.0)},
    "Чёрный скат": {"shell": (0.02, 0.02, 0.025), "trim": (0.0, 0.35, 0.45), "glow": (0.2, 0.95, 1.0), "eyes": (0.4, 1.0, 1.0)},
    "Рой пустоты": {"shell": (0.3, 0.0, 0.38), "trim": (1.0, 0.25, 0.65), "glow": (1.0, 0.4, 0.85), "eyes": (1.0, 0.65, 0.95)},
    "Гравикраб": {"shell": (0.01, 0.3, 0.08), "trim": (0.55, 0.95, 0.2), "glow": (0.5, 1.0, 0.4), "eyes": (0.6, 1.0, 0.5)},
    "Китёнок": {"shell": (0.25, 0.55, 0.95), "trim": (0.95, 0.97, 1.0), "glow": (0.5, 0.85, 1.0), "eyes": (0.6, 0.95, 1.0)},
    "Космический кит": {"shell": (0.03, 0.04, 0.22), "trim": (1.0, 0.7, 0.18), "glow": (1.0, 0.8, 0.35), "eyes": (1.0, 0.9, 0.6)},
}
SLOT_PAINT = ["plain", "swap", "candy"]

# A post: (zone, guardian name, [main, second, rare]); a kind: (id, name, family, shape, signature,
# extra colours).


POSTS = [
    # Debris Belt
    ("debris", "Слизень-сторож", [
        ("slimeWarden", "Слизень-сторож", "slime", {}, [siren], {}),
        ("patrolSwarm", "Патрульный рой", "swarm", {"count": 3, "main": 1.1}, [siren], {}),
        ("patrolRay", "Скат-патрульный", "ray", {"span": 1.1}, [siren], {}),
    ]),
    ("debris", "Краб-дрон", [
        ("crabDrone", "Краб-дрон", "crab", {"claws": (0.75, 0.75), "legs": 2, "w": 0.9}, [rotor], {}),
        ("droneRay", "Скат-дрон", "ray", {"span": 0.95, "droop": 6}, [rotor], {}),
        ("blimpWhale", "Кит-дирижабль", "whale", {"size": 1.0, "fins": 0.9}, [rotor], {}),
    ]),
    ("debris", "Лиловый краб", [
        ("violetCrab", "Лиловый краб", "crab", {"claws": (0.6, 1.8)}, [], {}),
        ("violetWorm", "Лиловый червь", "worm", {"segments": 5}, [pincers], {}),
        ("violetRay", "Лиловый скат", "ray", {"span": 1.3, "droop": 22}, [pincers], {}),
    ]),
    ("debris", "Кислотный слизень", [
        ("acidSlime", "Кислотный слизень", "slime", {"w": 0.72, "h": 1.55}, [bubbles], {}),
        ("acidWorm", "Кислотный червь", "worm", {"segments": 4, "r": 1.1}, [bubbles], {}),
        ("acidWhale", "Кислотный кит", "whale", {"size": 0.95}, [bubbles], {}),
    ]),
    ("debris", "Ржавый краб", [
        ("rustyCrab", "Ржавый краб", "crab", {"boxy": True, "w": 1.15, "legs": 4, "claws": (1.15, 1.15)}, [exhausts], {}),
        ("rustySwarm", "Ржавый рой", "swarm", {"count": 4, "main": 1.15}, [exhausts], {}),
        ("rustyWhale", "Ржавый кит", "whale", {"size": 1.1, "fins": 1.1}, [exhausts], {}),
    ]),
    ("debris", "Король слизней", [
        ("slimeKing", "Король слизней", "slime", {"w": 1.3, "h": 0.85}, [circlet], {}),
        ("royalSwarm", "Свита короля", "swarm", {"count": 4, "main": 1.0}, [circlet], {}),
        ("royalRay", "Королевский скат", "ray", {"span": 1.2, "droop": 16}, [circlet], {}),
    ]),
    # Ice Rings
    ("ice", "Ледяной червь", [
        ("iceWorm", "Ледяной червь", "worm", {"segments": 5}, [icicles], {}),
        ("iceSwarm", "Ледяной рой", "swarm", {"count": 3, "main": 1.15}, [icicles], {}),
        ("iceCrab", "Ледяной краб", "crab", {"w": 1.0, "claws": (1.1, 1.1)}, [icicles], {}),
    ]),
    ("ice", "Снежный краб", [
        ("snowCrab", "Снежный краб", "crab", {"w": 1.1, "claws": (0.9, 0.9)}, [snowcap], {}),
        ("snowSlime", "Снежный слизень", "slime", {"w": 1.15, "h": 0.95}, [snowcap], {}),
        ("snowWhale", "Снежный кит", "whale", {"size": 1.05}, [snowcap], {}),
    ]),
    ("ice", "Морозный слизень", [
        ("frostSlime", "Морозный слизень", "slime", {"w": 1.1, "h": 0.9}, [ice_crown], {}),
        ("flakeSwarm", "Рой снежинок", "swarm", {"count": 5, "main": 0.95}, [flakes], {}),
        ("frostRay", "Морозный скат", "ray", {"span": 1.15, "droop": 14}, [ice_crown, flakes], {}),
    ]),
    ("ice", "Хрустальный червь", [
        ("crystalWorm", "Хрустальный червь", "worm", {"segments": 5, "faceted": True}, [], {}),
        ("crystalSlime", "Хрустальный слизень", "slime", {"w": 0.95, "h": 1.2}, [ice_crown], {}),
        ("crystalWhale", "Хрустальный кит", "whale", {"size": 1.0}, [], {}),
    ]),
    ("ice", "Ледяной скат", [
        ("iceRay", "Ледяной скат", "ray", {"span": 1.15, "droop": 18}, [ice_fringe], {}),
        ("icebreakerCrab", "Краб-ледокол", "crab", {"boxy": True, "w": 1.0, "claws": (0.8, 0.8)}, [plow], {}),
        ("auroraSwarm", "Северное сияние", "swarm", {"count": 3, "main": 1.0}, [aurora], {"glow": (0.4, 1.0, 0.7)}),
    ]),
    ("ice", "Мать червей", [
        ("wormMother", "Мать червей", "worm", {"segments": 6, "r": 1.3}, [babies], {}),
        ("motherWhale", "Ледяная китиха", "whale", {"size": 1.15, "fins": 1.2}, [frill], {}),
        ("nannyRay", "Скат-няня", "ray", {"span": 1.2, "droop": 20}, [frill], {}),
    ]),
    # Red Nebula
    ("nebula", "Рой пожирателей", [
        ("devourerSwarm", "Рой пожирателей", "swarm", {"count": 3, "main": 1.2}, [mandibles], {}),
        ("devourerCrab", "Краб-пожиратель", "crab", {"w": 1.0, "claws": (1.2, 1.2)}, [mandibles], {}),
        ("devourerWorm", "Червь-пожиратель", "worm", {"segments": 6, "r": 1.15}, [mandibles], {}),
    ]),
    ("nebula", "Звёздный скат", [
        ("starRay", "Звёздный скат", "ray", {"span": 1.1}, [stars], {}),
        ("starSlime", "Звёздный слизень", "slime", {"w": 1.0, "h": 1.05}, [stars], {"core": (0.4, 0.45, 1.0)}),
        ("starWhale", "Звёздный кит", "whale", {"size": 1.1, "fins": 1.2}, [stars], {}),
    ]),
    ("nebula", "Огненный слизень", [
        ("fireSlime", "Огненный слизень", "slime", {"h": 1.1}, [flames], {}),
        ("fireWorm", "Огненный червь", "worm", {"segments": 5}, [flames], {}),
        ("fireWhale", "Огненный кит", "whale", {"size": 1.05}, [flames], {}),
    ]),
    ("nebula", "Красный рой", [
        ("redSwarm", "Красный рой", "swarm", {"count": 6, "main": 0.9}, [], {}),
        ("redCrab", "Красный краб", "crab", {"w": 0.95, "legs": 4}, [minions], {}),
        ("redRay", "Красный скат", "ray", {"span": 1.2, "droop": 10}, [minions], {}),
    ]),
    ("nebula", "Скат-молния", [
        ("lightningRay", "Скат-молния", "ray", {"span": 1.3, "droop": 5}, [lightning], {}),
        ("stormSlime", "Грозовой слизень", "slime", {"w": 1.0, "h": 1.0}, [lightning], {}),
        ("stormWhale", "Грозовой кит", "whale", {"size": 1.1}, [lightning], {}),
    ]),
    ("nebula", "Матка пожирателей", [
        ("devourerQueen", "Матка пожирателей", "swarm", {"count": 2, "main": 1.6}, [queen], {}),
        ("guardCrab", "Краб-гвардеец", "crab", {"boxy": True, "w": 1.05, "claws": (1.3, 1.3)}, [guard], {}),
        ("empressWorm", "Червь-императрица", "worm", {"segments": 6, "r": 1.3}, [guard], {}),
    ]),
    # Event Horizon
    ("horizon", "Теневой червь", [
        ("shadowWorm", "Теневой червь", "worm", {"segments": 6, "r": 0.85}, [smoke], {}),
        ("shadowSlime", "Теневой слизень", "slime", {"w": 1.0, "h": 1.1}, [smoke], {}),
        ("shadowCrab", "Теневой краб", "crab", {"w": 1.0, "claws": (1.0, 1.0)}, [smoke], {}),
    ]),
    ("horizon", "Чёрный скат", [
        ("blackRay", "Чёрный скат", "ray", {"span": 1.25, "droop": 20}, [star_dots], {}),
        ("eclipseSwarm", "Рой затмения", "swarm", {"count": 4, "main": 1.05}, [star_dots], {}),
        ("eclipseWhale", "Кит-затмение", "whale", {"size": 1.15}, [void_core], {}),
    ]),
    ("horizon", "Рой пустоты", [
        ("voidSwarm", "Рой пустоты", "swarm", {"count": 4, "main": 1.0}, [void_core], {}),
        ("voidSlime", "Слизень пустоты", "slime", {"w": 1.05, "h": 0.95}, [void_core], {}),
        ("voidRay", "Скат пустоты", "ray", {"span": 1.3, "droop": 24}, [void_core], {}),
    ]),
    ("horizon", "Гравикраб", [
        ("gravityCrab", "Гравикраб", "crab", {"w": 1.0}, [gravity], {}),
        ("gravityWorm", "Гравичервь", "worm", {"segments": 5}, [gravity], {}),
        ("gravitySwarm", "Гравирой", "swarm", {"count": 3, "main": 1.1}, [gravity], {}),
    ]),
    ("horizon", "Китёнок", [
        ("whaleCalf", "Китёнок", "whale", {"size": 0.75, "fins": 1.25}, [spout], {}),
        ("rayCalf", "Скатёнок", "ray", {"span": 0.8, "droop": 18}, [spout], {}),
        ("stargazerCrab", "Звездочёт", "crab", {"w": 0.9, "claws": (0.8, 0.8)}, [telescope], {}),
    ]),
    ("horizon", "Космический кит", [
        ("spaceWhale", "Космический Кит", "whale", {"size": 1.25, "fins": 1.3}, [galaxy], {}),
        ("spaceWorm", "Космический червь", "worm", {"segments": 6, "r": 1.05}, [galaxy], {}),
        ("galaxySlime", "Галактический слизень", "slime", {"w": 1.15, "h": 1.0}, [galaxy], {"core": (0.6, 0.3, 0.9)}),
    ]),
]

ZONE_TITLES = {"debris": "Пояс обломков", "ice": "Ледяные кольца", "nebula": "Красная туманность", "horizon": "Горизонт событий"}

# Every kind, flat: (id, name, family, zone, colours, shape, signature, post index, slot).
KINDS = []
for post_index, (zone, guardian, kinds) in enumerate(POSTS):
    assert len(kinds) == 3, f"post {post_index + 1} needs three kinds"
    for slot, (kind_id, name, family, shape, signature, extra) in enumerate(kinds):
        look = {**PALETTE[guardian], **extra, "paint": SLOT_PAINT[slot]}
        KINDS.append((kind_id, name, family, zone, look, shape, signature, post_index, slot))


def build(kind, tier, x, z, meteor=False):
    """One kind at base point (x, 0, z), grown to `tier`."""
    _, _, family, zone, look, shape, signature = kind[:7]
    return robo.build(family, zone, tier, x, z, meteor, look, shape, signature)
