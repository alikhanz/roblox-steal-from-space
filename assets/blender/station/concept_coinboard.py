# Concept renders for the coin board in the middle of the central station (user, 2026-11-10: "the
# leaderboard looks crude, make a big one in the middle"; the kiosks stand round it facing in).
# Three directions in the kiosks' style (pearl shells, navy screens, gold for coins), each seen
# from the station's spawn with the four capsule kiosks round it and a player for scale. A draft
# for review, not the final look.
#
#   tower  - a pearl tower with a screen on each of its four sides, a gold coin turning on top;
#   podium - a three-step podium for the top three, their names floating over the steps, the
#            rest of the top on a tall screen behind;
#   crown  - a round dais with a coin hologram, four tilted screens round it at head height under
#            a gold ring.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/station/concept_coinboard.py -- <outdir> [direction ...] [--fast]

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))

import bpy  # noqa: E402
import concept_kiosks as k  # noqa: E402
import real  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
POSITIONAL = [a for a in ARGS if not a.startswith("--")]
OUT_DIR = os.path.abspath(POSITIONAL[0] if POSITIONAL else "out/station")
DIRECTIONS = POSITIONAL[1:] or ["tower", "podium", "crown"]

GOLD = (1.0, 0.78, 0.25)
SILVER = (0.8, 0.85, 0.95)
BRONZE = (0.95, 0.52, 0.25)
PLACE_COLOURS = [GOLD, SILVER, BRONZE]
TITLE = "ЛУЧШИЕ ПО МОНЕТАМ"
ROWS = [
    ("Звёздный_Кот", "48,2K"),
    ("PixelMax", "31,7K"),
    ("Ракета2014", "19,0K"),
    ("nova_girl", "12,5K"),
    ("Космо_Лис", "8,9K"),
    ("ZeroG_Bob", "6,1K"),
    ("Пончик", "4,4K"),
]
# The kiosks' circle (StationShape: radius 0.6 of the 60-stud platform, on the diagonals).
KIOSK_RADIUS = 36.0


def gold():
    return k.glow(GOLD, 3.5)


def coin_metal():
    return k.cached("coin", lambda: real.gloss("Coin", GOLD, 0.2, 1.0))


def placed(build, turn=0.0, at=(0, 0, 0)):
    """Runs `build` (which faces -Y at the origin) and turns its objects about Z by `turn`, then
    moves them to `at`."""
    before = set(bpy.data.objects)
    build()
    move = Matrix.Translation(Vector(at)) @ Matrix.Rotation(turn, 4, "Z")
    for obj in set(bpy.data.objects) - before:
        if obj.parent is None:
            obj.matrix_world = move @ obj.matrix_world


def text_left(body, at, size, mat):
    obj = k.text(body, at, size, mat)
    obj.data.align_x = "LEFT"
    return obj


def text_right(body, at, size, mat):
    obj = k.text(body, at, size, mat)
    obj.data.align_x = "RIGHT"
    return obj


def screen(width, height, rows, first_place=1, title=True, line=None):
    """A navy screen facing -Y at the origin (its middle), a gold frame round it, the top drawn on
    it: the title, then `rows` from `first_place`, `line` apart."""
    frame = max(0.7, height * 0.03)
    # A pearl back, a thin gold rim peeking round the navy face.
    k.rounded_box((0, 0.45, 0), (width + frame * 1.6, 0.6, height + frame * 1.6), k.pearl(), 0.5 + frame)
    k.rounded_box((0, 0.1, 0), (width + frame, 0.3, height + frame), gold(), 0.5 + frame / 2)
    k.rounded_box((0, 0, 0), (width, 0.4, height), k.navy(), 0.4 + frame / 2)
    line = line or height * 0.115
    top = height / 2 - line * 1.05
    if title:
        k.text(TITLE, (0, -0.25, top), line * 0.62, k.glow(GOLD, 2.5))
        top -= line * 1.15
    for i, (name, coins) in enumerate(rows):
        place = first_place + i
        z = top - i * line
        colour = PLACE_COLOURS[place - 1] if place <= 3 else (0.9, 0.93, 1.0)
        mat = k.glow(colour, 2.2)
        text_left(f"{place}", (-width / 2 + width * 0.06, -0.25, z), line * 0.6, mat)
        text_left(name, (-width / 2 + width * 0.16, -0.25, z), line * 0.55, k.glow((0.92, 0.94, 1.0), 2.0))
        text_right(coins, (width / 2 - width * 0.06, -0.25, z), line * 0.55, k.glow(GOLD, 2.2))


def coin(at, radius):
    """A gold coin standing on its edge, facing -Y, a glowing rim and a raised ring on its face."""
    at = Vector(at)
    k.cylinder(at, radius, radius * 0.22, coin_metal(), rotation=(math.pi / 2, 0, 0))
    k.torus(at, radius, radius * 0.09, gold(), rotation=(math.pi / 2, 0, 0))
    k.torus(at - Vector((0, radius * 0.11, 0)), radius * 0.62, radius * 0.07, gold(), rotation=(math.pi / 2, 0, 0))


def base_disc(radius):
    k.cylinder((0, 0, 0.4), radius, 0.8, k.navy())
    k.torus((0, 0, 0.12), radius, 0.2, gold())


# --- Directions --------------------------------------------------------------------------------


def tower():
    """A pearl tower, a screen on each side, a coin turning on top."""
    base_disc(7.5)
    k.rounded_box((0, 0, 9.3), (9.5, 9.5, 17.0), k.pearl(), 1.8)
    for side in range(4):
        # The screen on the tower's side.
        placed(lambda: placed(lambda: screen(7.4, 11.0, ROWS[:6]), 0, (0, -5.0, 0)), side * math.pi / 2, (0, 0, 10.5))
    k.torus((0, 0, 17.9), 4.0, 0.25, gold())
    k.cylinder((0, 0, 18.4), 2.0, 1.0, k.pearl(), radius2=1.2)
    coin((0, 0, 22.4), 3.0)


def podium():
    """Three steps for the top three, their names floating over them, the rest behind."""
    base_disc(9.5)
    steps = [(0, 4.6, 0), (-5.4, 3.0, 1), (5.4, 1.8, 2)]
    for x, height, index in steps:
        colour = PLACE_COLOURS[index]
        k.rounded_box((x, 0, 0.8 + height / 2), (5.2, 5.0, height), k.pearl(), 0.7)
        k.rounded_box((x, -2.52, 0.8 + height - 0.35), (4.6, 0.1, 0.3), k.glow(colour, 4.0), 0.04)
        k.text(str(index + 1), (x, -2.65, 0.8 + height / 2 - 0.2), 2.4, k.glow(colour, 3.0))
        # The player's plate floating over their step.
        name, coins = ROWS[index]
        plate = Vector((x, -0.5, 0.8 + height + 3.2))
        k.rounded_box(plate, (4.9, 0.3, 2.3), k.navy(), 0.5)
        k.rounded_box(plate + Vector((0, 0.1, 0)), (5.3, 0.25, 2.7), k.glow(colour, 3.0), 0.6)
        k.text(name, plate + Vector((0, -0.25, 0.42)), 0.62, k.glow((0.92, 0.94, 1.0), 2.0))
        k.text(coins, plate + Vector((0, -0.25, -0.45)), 0.62, k.glow(GOLD, 2.4))
        k.torus(plate + Vector((0, 0, 2.0)), 0.7, 0.16, k.glow(colour, 4.0), rotation=(math.pi / 2, 0, 0))
    # The rest of the top on a tall screen behind, on two pearl posts.
    for side in (-1, 1):
        k.pill((side * 8.6, 4.2, 8.5), 15.0, 0.55, k.pearl())
    placed(lambda: screen(15.0, 9.0, ROWS[3:7], first_place=4), 0, (0, 4.2, 13.5))
    coin((0, 4.2, 20.6), 2.2)


def crown():
    """A round dais with a coin hologram, four tilted screens round it at head height."""
    k.cylinder((0, 0, 0.6), 7.5, 1.2, k.pearl())
    k.torus((0, 0, 1.2), 7.5, 0.25, gold())
    k.pill((0, 0, 9.0), 16.0, 0.9, k.pearl())
    coin_holo = k.cached("coinholo", lambda: k.holo(GOLD))
    k.cylinder((0, 0, 7.0), 3.6, 0.5, coin_holo, rotation=(math.pi / 2, 0, 0.5))
    k.torus((0, 0, 7.0), 3.6, 0.15, gold(), rotation=(math.pi / 2, 0, 0.5))
    for side in range(4):
        def one():
            # Tilted down a little towards the players below, on an arm from the pillar.
            before = set(bpy.data.objects)
            screen(9.0, 6.6, ROWS[:5])
            tilt = Matrix.Rotation(math.radians(12), 4, "X")
            out = Matrix.Translation((0, -6.6, 0)) @ tilt
            for obj in set(bpy.data.objects) - before:
                obj.matrix_world = out @ obj.matrix_world
            k.rounded_box((0, -3.6, 0), (0.6, 5.6, 0.6), k.pearl(), 0.25)
        placed(one, side * math.pi / 2, (0, 0, 15.0))
    k.torus((0, 0, 19.6), 6.2, 0.35, gold())
    coin((0, 0, 21.8), 1.8)


# The big crown (user, 2026-11-10: "bigger and higher, distances in space are big"): readable from
# the islands (~340 studs), high over the kiosks.
BIG = {"width": 36.0, "height": 26.0, "out": 20.0, "z": 38.0, "tilt": 22.0, "ring": 56.0}


def crown_big():
    k.cylinder((0, 0, 0.8), 14.0, 1.6, k.pearl())
    k.torus((0, 0, 1.6), 14.0, 0.45, gold())
    k.cylinder((0, 0, BIG["ring"] / 2), 2.0, BIG["ring"], k.pearl(), vertices=32)
    coin_holo = k.cached("coinholo", lambda: k.holo(GOLD))
    k.cylinder((0, 0, 17.0), 8.0, 1.0, coin_holo, rotation=(math.pi / 2, 0, 0))
    k.torus((0, 0, 17.0), 8.0, 0.35, gold(), rotation=(math.pi / 2, 0, 0))
    for side in range(4):
        def one():
            before = set(bpy.data.objects)
            screen(BIG["width"], BIG["height"], ROWS[:5], line=BIG["height"] * 0.8 / 6.2)
            tilt = Matrix.Rotation(math.radians(BIG["tilt"]), 4, "X")
            out = Matrix.Translation((0, -BIG["out"], 0)) @ tilt
            for obj in set(bpy.data.objects) - before:
                obj.matrix_world = out @ obj.matrix_world
            for z in (-8.0, 8.0):
                k.rounded_box((0, -BIG["out"] / 2, z), (1.2, BIG["out"] - 2, 1.2), k.pearl(), 0.5)
        placed(one, side * math.pi / 2, (0, 0, BIG["z"]))
    k.torus((0, 0, BIG["ring"]), 30.0, 1.0, gold())
    coin((0, 0, BIG["ring"] + 8.0), 5.0)


BUILDERS = {"tower": tower, "podium": podium, "crown": crown, "crown_big": crown_big}


def station_reference():
    """The ring over the dome and the platform's rim, for scale in the far views."""
    k.torus((0, 0, 92.0), 92.5, 2.0, k.cached("steel", lambda: real.gloss("Steel", (0.45, 0.47, 0.55), 0.3, 0.8)))
    k.torus((0, 0, 0.0), 61.0, 1.0, k.glow((0.35, 0.78, 1.0), 4.0))


def kiosks():
    for i, (label, colour, kind) in enumerate(k.STALLS):
        angle = math.pi / 4 + i * math.pi / 2
        at = (math.cos(angle) * KIOSK_RADIUS, math.sin(angle) * KIOSK_RADIUS, 0)
        # The pod faces -Y; turn it to face the middle.
        turn = math.atan2(-at[1], -at[0]) + math.pi / 2
        placed(lambda: k.pod(0, label, colour, kind), turn, at)


# Where each view looks from and at, and its lens; "far" is a player on their island (~340 studs
# off) with Roblox's default 70° vertical field of view.
VIEWS = {
    "near": ((3, -31, 8), (0, 0, 11), {"lens": 22}),
    "spawn": ((6, -52, 6), (0, 0, 30), {"lens": 16}),
    "far": ((0, -340, 6), (0, 0, 45), {"angle": 70}),
    "far_zoom": ((0, -340, 6), (0, 0, 40), {"angle": 14}),
}


def render(name, view="near"):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    eevee = scene.eevee
    for attribute, value in (("use_raytracing", not k.FAST), ("taa_render_samples", 16 if k.FAST else 64)):
        if hasattr(eevee, attribute):
            setattr(eevee, attribute, value)
    if hasattr(eevee, "shadow_pool_size"):
        eevee.shadow_pool_size = "1024"
    scene.render.resolution_x, scene.render.resolution_y = (960, 540) if k.FAST else (1920, 1080)
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.3
    where, target, optics = VIEWS[view]
    cam_data = bpy.data.cameras.new("Cam")
    if "angle" in optics:
        cam_data.sensor_fit = "VERTICAL"
        cam_data.angle_y = math.radians(optics["angle"])
    else:
        cam_data.lens = optics["lens"]
    cam_data.clip_end = 2000
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = where
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    suffix = "" if view == "near" else f"_{view}"
    scene.render.filepath = os.path.join(OUT_DIR, f"coinboard_{name}{suffix}.png")
    bpy.ops.render.render(write_still=True)
    print("Wrote", scene.render.filepath)


for direction in DIRECTIONS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    k._cache.clear()
    k.space()
    k.lights()
    bpy.ops.mesh.primitive_cylinder_add(radius=60, depth=1, location=(0, 0, -0.5), vertices=96)
    real.assign(k.active(), k.floor_mat())
    kiosks()
    placed(BUILDERS[direction])
    k.roblox_player((-4.5, -17, 0))
    if direction == "crown_big":
        station_reference()
        for view in ("spawn", "far", "far_zoom"):
            render(direction, view)
    else:
        render(direction)
