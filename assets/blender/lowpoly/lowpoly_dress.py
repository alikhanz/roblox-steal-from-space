# Concept (low-poly pets): a rolled outfit. Instead of one fixed outfit a tier (every epic wears the
# same fairy wings), each pet rolls its pieces from its tier's pools: a head piece, an aura, and from
# rare up a back piece (a jetpack, then wings). Colours always follow the tier: grey, green, blue,
# violet, gold. All pieces are shared meshes of the library, so variety costs a few meshes, not more.
#
# The roll is a function of a seed: the game would hash the owner's UserId and the alien's uid (both
# known already, nothing new saved), so a pet looks the same after a rejoin, on any place, to every
# player.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lowpoly_pets as pets  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

D = math.radians

# --- Pools ---------------------------------------------------------------------------------------------
# Each slot's pool by tier; None is "nothing in this slot". A roll is an index into a pool, so a
# changed pool would change the looks of pets already hatched (see the README on keeping them).
HEAD = ["horns", "crest", "feelers"]
AURA_LOW = ["halo", "shards"]
AURA = ["halo", "shards", "rings"]
WINGS = ["fairy", "feather", "mech", "crystal"]
POOLS = {
    0: {"head": HEAD + [None]},
    1: {"head": HEAD, "aura": AURA_LOW},
    2: {"head": HEAD, "aura": AURA, "back": ["jetpack", "featherSmall"]},
    3: {"head": HEAD, "aura": AURA, "back": WINGS},
    4: {"head": ["crown"], "aura": AURA + ["star"], "back": WINGS},
}
SLOTS = ("head", "aura", "back")


def fnv1a(text):
    """32-bit FNV-1a with a final mix: what the game would hash `<UserId>:<uid>` with (easy to write in
    Luau). Without the mix, neighbouring uids differ only in the low bits and roll the same pieces."""
    value = 0x811C9DC5
    for byte in text.encode():
        value = ((value ^ byte) * 0x01000193) & 0xFFFFFFFF
    value ^= value >> 16
    value = (value * 0x85EBCA6B) & 0xFFFFFFFF
    value ^= value >> 13
    value = (value * 0xC2B2AE35) & 0xFFFFFFFF
    return value ^ (value >> 16)


def roll(seed, tier):
    """The pieces of a pet: one per slot of its tier, each drawn from its own bits of the seed."""
    value = fnv1a(str(seed))
    picks = {}
    for index, slot in enumerate(SLOTS):
        pool = POOLS[tier].get(slot)
        if pool:
            picks[slot] = pool[(value >> (index * 8)) % len(pool)]
    return picks


# --- Pieces (shared meshes, composed once from the style's shapes) ------------------------------------------


def _mesh(ctx, name):
    library = ctx.pet.library
    if name == "feather":
        # Five long blades fanning out from the root: a bird's wing.
        pieces = []
        for i in range(5):
            angle = D(12 + i * 16)
            length = 0.45 + 0.09 * i
            direction = Vector((math.sin(angle), 0, math.cos(angle)))
            pieces.append(("ball", tuple(direction * length * 0.95), (0.075, 0.03, length), (0, angle, 0)))
        return library.compose("feather", pieces)
    if name == "mech_frame":
        # A strut out from the root and three ribs down from it: a mechanical wing's frame.
        pieces = [("can", (0.45, 0, 0.62), (0.035, 0.035, 0.5), (0, D(55), 0))]
        for i in range(3):
            x = 0.3 + i * 0.28
            pieces.append(("can", (x, 0, 0.62 + (x - 0.45) * 0.7 - 0.3), (0.025, 0.025, 0.32), (0, D(-12), 0)))
        return library.compose("mech_frame", pieces)
    if name == "mech_panel":
        pieces = []
        for i in range(3):
            x = 0.38 + i * 0.28
            pieces.append(("block", (x, 0, 0.62 + (x - 0.45) * 0.7 - 0.28), (0.13, 0.012, 0.3), (0, D(-12), 0)))
        return library.compose("mech_panel", pieces)
    if name == "crystal_wing":
        pieces = []
        for i, (angle, length) in enumerate(((20, 1.0), (42, 0.8), (64, 0.55))):
            pieces.append(("cone", (0, 0, 0), (0.22, 0.08, length * 1.25), (0, D(angle), 0)))
        return library.compose("crystal_wing", pieces)
    if name == "shards":
        pieces = []
        for i in range(5):
            angle = i / 5 * math.tau
            pieces.append(("ball", (math.cos(angle), math.sin(angle), 0.18 * math.sin(i * 2.1)), (0.08, 0.08, 0.13), (0, 0, angle)))
        return library.compose("shards", pieces)
    if name == "orbits":
        return library.compose("orbits", [("seam", (0, 0, 0), (1, 1, 1), (D(18), 0, 0)), ("seam", (0, 0, 0), (1.12, 1.12, 1.12), (D(-14), D(10), 0))])
    if name == "horns":
        pieces = []
        for side in (-1, 1):
            pieces.append(("cone", (side * 0.22, 0, 0), (0.09, 0.09, 0.38), (D(-18), D(side * 28), 0)))
        return library.compose("horns", pieces)
    if name == "crest":
        return library.compose("crest", [("cone", (0, -0.18 + i * 0.18, 0), (0.035, 0.13, h), (D(18), 0, 0)) for i, h in enumerate((0.3, 0.42, 0.3))])
    if name == "feelers":
        pieces = []
        for side in (-1, 1):
            tip = Vector((side * 0.3, -0.08, 0.42))
            pieces.append(("can", tuple(tip / 2 + Vector((side * 0.06, 0, 0))), (0.022, 0.022, 0.22), (D(8), D(side * 30), 0)))
            pieces.append(("ball", tuple(tip + Vector((side * 0.04, 0, 0.02))), (0.07,) * 3, (0, 0, 0)))
        return library.compose("feelers", pieces)
    raise KeyError(name)


def _wing_pair(ctx, info, size, put_side):
    (cx, cy, cz), (a, b, c) = info["hull"]
    r = info["radius"]
    span = (0.8 + 0.25 * r) * size * 2.0
    for side in (-1, 1):
        hinge = pets.on_hull(info, (cx + side * r * 0.35, cy + r * 0.5, cz + 0.35), -0.03)
        turn = Euler((D(-10), 0, D(side * pets.WING_SWEEP))).to_matrix() @ (Matrix.Rotation(math.pi, 3, "Z") if side < 0 else Matrix.Identity(3))
        put_side(hinge, span, tuple(turn.to_euler()), "wingL" if side < 0 else "wingR")


def back(ctx, info, piece):
    size = 0.85 if ctx.tier == 3 else 1.0
    if piece == "jetpack":
        pets.jetpack(ctx, info)
    elif piece == "fairy":
        pets.wings(ctx, info, size)
    elif piece in ("feather", "featherSmall"):
        mesh = _mesh(ctx, "feather")
        scale = 0.55 if piece == "featherSmall" else size
        _wing_pair(ctx, info, scale, lambda at, span, rot, role: ctx.put(mesh, at, span * 0.75, "tierBody", rot, role))
    elif piece == "mech":
        frame, panel = _mesh(ctx, "mech_frame"), _mesh(ctx, "mech_panel")

        def put(at, span, rot, role):
            ctx.put(frame, at, span * 0.8, "engine", rot, role)
            ctx.put(panel, at, span * 0.8, "wing", rot, role)

        _wing_pair(ctx, info, size, put)
    elif piece == "crystal":
        mesh = _mesh(ctx, "crystal_wing")
        _wing_pair(ctx, info, size, lambda at, span, rot, role: ctx.put(mesh, at, span * 0.9, "wing", rot, role))


def aura(ctx, info, piece):
    (cx, cy, cz), (a, b, c) = info["hull"]
    r = info["radius"]
    if piece == "halo":
        x, y = info["top"][0], info["top"][1]
        top = pets.top_height(info, x, y)
        lift = 0.75 if ctx.tier == 4 else 0.45
        ctx.put("ring", (x, y, top + lift), (0.36, 0.36, 0.5), "tier", role="halo")
    elif piece == "shards":
        ctx.put(_mesh(ctx, "shards"), (cx, cy, cz + 0.1), r * 1.15, "wing", role="orbit")
    elif piece == "rings":
        # Low round the body, under the eyes: rings across the face hide it.
        ctx.put(_mesh(ctx, "orbits"), (cx, cy, cz - 0.55 * c), r * 1.05, "tier", role="orbit")
    elif piece == "star":
        pets.star(ctx, info)


def head(ctx, info, piece):
    if piece is None:
        return
    if piece == "crown":
        pets.crown(ctx, info)
        return
    x, y = info["top"][0], info["top"][1]
    # Off-centre a little to the front, clear of a signature on the very top.
    y -= 0.15 * info["hull"][1][1]
    z = pets.top_height(info, x, y) - 0.04
    scale = min(1.25, max(0.8, info["radius"] / 0.9))
    ctx.put(_mesh(ctx, piece), (x, y, z), scale, "tierBody")


def dresser(picks):
    """The outfit as a function for lowpoly_pets.build."""

    def dress(ctx, info):
        head(ctx, info, picks.get("head"))
        aura(ctx, info, picks.get("aura"))
        back(ctx, info, picks.get("back"))

    return dress


LABELS = {"horns": "рожки", "crest": "гребень", "feelers": "усики", None: "—", "halo": "нимб", "shards": "осколки", "rings": "кольца",
          "star": "звезда", "jetpack": "ранец", "featherSmall": "крылышки", "fairy": "стрекоза", "feather": "перья", "mech": "механика",
          "crystal": "кристаллы", "crown": "корона"}


# --- For the game: where each slot sits on a kind, and the pieces as a kit ------------------------------
# The game builds a pet from its kind's body and dresses it in code (decision 118): it clones a piece
# of the kit and puts its origin on the body's point for the slot, scaled by the point's scale.


def anchors(info):
    """The body's points for the outfit, at the body's own size (tier 2): slot -> (point, scale)."""
    (cx, cy, cz), (a, b, c) = info["hull"]
    r = info["radius"]
    x, y, top = info["top"]
    head_y = y - 0.15 * b
    points = {
        "Head": ((x, head_y, pets.top_height(info, x, head_y) - 0.04), min(1.25, max(0.8, r / 0.9))),
        "Halo": ((x, y, pets.top_height(info, x, y) + 0.45), 1.0),
        "Aura": ((cx, cy, cz + 0.1), r * 1.15),
        "Rings": ((cx, cy, cz - 0.55 * c), r * 1.05),
        "Star": ((cx, cy + b * 0.95, cz + 0.25), r * 1.6),
        "Orbit": ((cx, cy, cz + 0.45), r),
    }
    for side in (-1, 1):
        hinge = pets.on_hull(info, (cx + side * r * 0.35, cy + r * 0.5, cz + 0.35), -0.03)
        points["Wing" + ("L" if side < 0 else "R")] = (hinge, (0.8 + 0.25 * r) * 2.0)
    tanks = [Vector(pets.on_hull(info, (cx + side * 0.26, cy + b, cz + info.get("engine_z", 0.0)), 0.06)) for side in (-1, 1)]
    points["Pack"] = (tuple((tanks[0] + tanks[1]) / 2), 1.0)
    radius = info.get("crown_r", 0.32)
    crown_z = min(pets.top_height(info, x + math.cos(t) * radius, y + math.sin(t) * radius) for t in (0, math.pi / 2, math.pi, 1.5 * math.pi))
    points["Crown"] = ((x, y, crown_z + 0.08 + info.get("crown_lift", 0.0)), radius)
    return points


def _turn(side):
    """A wing's rest pose: swept back, the left one the same flat wing turned half round."""
    return Euler((D(-10), 0, D(side * pets.WING_SWEEP))).to_matrix() @ (Matrix.Rotation(math.pi, 3, "Z") if side < 0 else Matrix.Identity(3))


def kit(ctx):
    """Every piece at its origin, scale 1: name -> ([(mesh, point, scale, paint key, rotation, role)],
    [(dust marker name, point)]). A wing's origin is its hinge; the rest's, where its slot's point is."""
    pieces = {}
    for side in (-1, 1):
        s = "L" if side < 0 else "R"
        rotation = tuple(_turn(side).to_euler())
        role = "wing" + s
        dust = []
        for index, (x, y) in enumerate(robo_wing_dust()):
            dust.append((f"dust{s}{index + 1}", tuple(_turn(side) @ Vector((x, 0.0, y)))))
        pieces["wingFairy" + s] = ([("wing", (0, 0, 0), 1.0, "wing", rotation, role), ("wing_edge", (0, 0, 0), 1.0, "wingEdge", rotation, role)], dust)
        pieces["wingFeather" + s] = ([(_mesh(ctx, "feather"), (0, 0, 0), 0.75, "tierBody", rotation, role)], [])
        pieces["wingMech" + s] = ([(_mesh(ctx, "mech_frame"), (0, 0, 0), 0.8, "engine", rotation, role),
                                    (_mesh(ctx, "mech_panel"), (0, 0, 0), 0.8, "wing", rotation, role)], [])
        pieces["wingCrystal" + s] = ([(_mesh(ctx, "crystal_wing"), (0, 0, 0), 0.9, "tierGlass", rotation, role)], [])
    tank = ctx.pet.library.compose("tank", [
        ("can", (0, 0, 0), (0.11, 0.11, 0.21), (0, 0, 0)),
        ("ball", (0, 0, 0.21), (0.11, 0.11, 0.07), (0, 0, 0)),
        ("cone", (0, 0, -0.36), (0.13, 0.13, 0.17), (0, 0, 0)),
    ])
    pack = []
    jet_turn = tuple(Vector((0, 0.3, -1)).to_track_quat("Z", "Y").to_euler())
    for side in (-1, 1):
        x = side * 0.26
        pack += [(tank, (x, 0, 0), 1.0, "engine", (0, 0, 0), "body"),
                 ("seam", (x, 0, 0.06), (0.115, 0.115, 0.6), "tier", (0, 0, 0), "body"),
                 ("cone", (x, 0, -0.33), (0.07, 0.07, 0.32), "jet", jet_turn, "body")]
    pieces["jetpack"] = (pack, [])
    for name in ("horns", "crest", "feelers"):
        pieces[name] = ([(_mesh(ctx, name), (0, 0, 0), 1.0, "tierBody", (0, 0, 0), "body")], [])
    pieces["halo"] = ([("ring", (0, 0, 0), (0.36, 0.36, 0.5), "tier", (0, 0, 0), "body")], [])
    pieces["shards"] = ([(_mesh(ctx, "shards"), (0, 0, 0), 1.0, "tierGlass", (0, 0, 0), "orbit")], [])
    pieces["rings"] = ([(_mesh(ctx, "orbits"), (0, 0, 0), 1.0, "tier", (0, 0, 0), "orbit")], [])
    pieces["star"] = ([("star", (0, 0, 0), 1.0, "gold", (0, 0, 0), "body")], [])
    pieces["planet"] = ([("ball", (0, 0, 0), 0.1, "planet", (0, 0, 0), "orbit")], [])
    crown_pieces = []
    gems = []
    for index in range(5):
        angle = index / 5 * math.tau - math.pi / 2
        out = Vector((math.cos(angle) * 0.25, math.sin(angle) * 0.25, 1)).normalized()
        base = Vector((math.cos(angle) * 0.94, math.sin(angle) * 0.94, -0.06))
        spike = (0.42 if index == 0 else 0.3) / 0.32
        crown_pieces.append(("cone", tuple(base), (0.26, 0.26, spike), tuple(out.to_track_quat("Z", "Y").to_euler())))
        gems.append(("dot", tuple(base + out * spike), (0.18,) * 3, (0, 0, 0)))
    library = ctx.pet.library
    crown_mesh = library.compose("crown", [("ring", (0, 0, -0.05 / 0.32), (1.0, 1.0, 2.2), (0, 0, 0))] + crown_pieces)
    pieces["crown"] = ([(crown_mesh, (0, 0, 0), 1.0, "gold", (0, 0, 0), "body"), (library.compose("gems", gems), (0, 0, 0), 1.0, "gemPink", (0, 0, 0), "body")], [])
    return pieces


def robo_wing_dust():
    import robo

    return robo._from_trace(robo.WING_DUST_TRACE)
