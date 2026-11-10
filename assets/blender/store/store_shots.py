# The game page's pictures (docs/design/screens/game-page.md; docs/plans/STAGE_9.md, "Страница
# игры"), one function a shot, built from store_scene.py: the standard Roblox character with a
# jetpack holding a glowing egg up while a guardian lunges at it, in bright space (the genre's
# hero shot, user 2026-11-11), and more thumbnails from the game's own models.
#
# Shots: icon (the 1024 render of the 512 icon), hero-thumb (thumbnail 1), hatch (2), zones (3),
# emblem (the community's), pilot (a check of the pilot from four sides).
#
# Run headless from the repo root (Blender by full path, docs/design/BLENDER_ROBLOX.md):
#   blender --background --factory-startup --python assets/blender/store/store_shots.py -- <outdir> <shot ...> [--outline] [--fast]
# --outline draws the cartoon line (every final picture has it); --fast renders half size, fewer samples.
# preview_sizes.py then checks the icon at phone size and writes the 512 px files.

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import store_scene as s  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FAST = "--fast" in ARGS
OUTLINE = "--outline" in ARGS
POSITIONAL = [a for a in ARGS if not a.startswith("--")]
OUT_DIR = os.path.abspath(POSITIONAL[0] if POSITIONAL else "out/store")
SHOTS = POSITIONAL[1:]

ICON = (1024, 1024)
THUMB = (1920, 1080)


def reset(resolution):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s.setup(resolution, FAST)
    s.world()


def finish(name):
    if OUTLINE:
        objects = list(bpy.context.scene.objects)
        # Specks (pets' dust, studs, sparks) get no line: at full size a 3 px line fills them black.
        tiny = [o for o in objects if o.type == "MESH" and max(o.dimensions) < 0.25 * max(1.0, max(o.scale))]
        s.outline(3.0 if not FAST else 1.5, set(s.glowing(objects)) | set(tiny))
    s.render(os.path.join(OUT_DIR, f"{name}.png"))


def lights(key=(-14, -24, 16), rim=(20, 30, 12), target=(0, 0, 0), power=1.0):
    s.area_light(key, target, (1.0, 0.96, 0.9), 26000 * power, 14)
    s.area_light(rim, target, (0.4, 0.75, 1.0), 45000 * power, 30)
    s.area_light((target[0] + 20, target[1] - 26, target[2] - 6), target, (0.7, 0.75, 1.0), 6000 * power, 20)



# --- Hero: the genre's icon, in space ---------------------------------------------------------------------


def hero_pilot(location, rotation, scale, egg_rarity, body_yaw=-58, head_turn=0, grade=9, arms="trophy"):
    """The standard Roblox character holding a big glowing egg up in one hand (`arms="trophy"`;
    "overhead" is both hands), the body turned three-quarter so the jetpack shows, flames below."""
    objects, flames = s.avatar_pilot(arms=arms, legs="run", head_turn=head_turn, grade=grade, pack_scale=1.5, arm_back=184 if arms == "trophy" else 202)
    egg_objects = s.egg(egg_rarity, halo=0.0, light=0.0)
    # The window faces the viewer whatever the body's turn.
    held = (-1.55, 0.0, 4.35) if arms == "trophy" else (0, -0.1, 4.15)
    s.place(egg_objects, s.pose(held, (4, 0, -body_yaw - 18), 1.6))
    objects += egg_objects
    for at, direction in flames:
        objects += s.flame(at, direction, length=8.0, radius=0.6)
    s.place(objects, s.pose((0, 0, 0), (0, 0, body_yaw)))
    s.place(objects, s.pose(location, rotation, scale))
    return objects


def egg_glow(objects, rarity):
    """Light behind the held egg (a soft disc of its colour, not over it) and twinkles round it."""
    shells = [o for o in objects if o.name.startswith(("Body", "CapGold")) or o.name == f"Glow{rarity}"]
    low, high = s.bounds(shells)
    centre = (low + high) / 2
    radius = (high.z - low.z) / 2
    color = s.EGG_LIGHT[rarity]
    s.glow_ball(centre + Vector((0, 22, 0)), radius * 2.6, color, 5.0, 3.0, 0.8)
    s.point_light(centre + Vector((0, -radius * 2.2, radius * 0.6)), color, 1200, 1.0)
    for dx, dz, size, turn in ((1.15, 0.85, 0.45, 0.3), (1.3, -0.3, 0.28, 0.0), (-1.05, 0.9, 0.3, 0.4)):
        s.sparkle(centre + Vector((dx * radius, -radius, dz * radius)), size * radius, turn=turn)


# Backdrops for the A/B variants: (inner glow, outer, glow centre, nebula colours, planet bands).
SKIES = {
    "violet": ((0.25, 0.55, 1.0), (0.12, 0.03, 0.32), (-0.45, 0.5), ((0.9, 0.25, 0.8), (0.1, 0.7, 0.95)),
               ((0.35, 0.2, 0.75), (0.95, 0.45, 0.8), (0.3, 0.8, 1.0))),
    "teal": ((0.2, 0.85, 0.95), (0.02, 0.1, 0.3), (-0.45, 0.5), ((0.1, 0.5, 0.9), (0.2, 0.95, 0.75)),
             ((0.1, 0.35, 0.7), (0.35, 0.85, 0.9), (0.9, 0.95, 1.0))),
    "sunset": ((1.0, 0.55, 0.25), (0.25, 0.04, 0.3), (-0.45, 0.5), ((1.0, 0.3, 0.5), (0.95, 0.6, 0.2)),
               ((0.6, 0.2, 0.5), (1.0, 0.55, 0.35), (1.0, 0.85, 0.5))),
}


def hero(thumb=False, guardian="devourerSwarm", egg_rarity="Legendary", name="hero", sky="violet"):
    """Square: the pilot in the lower left with the egg held high, the guardian lunging in from the
    right, filling the frame; a bright nebula, a planet below, speed lines behind the guardian."""
    reset(THUMB if thumb else ICON)
    bpy.context.scene.view_settings.exposure = -0.1
    s.world((0.55, 0.42, 0.5))
    s.sun((0.35, 0.75, -0.55), (1.0, 0.93, 0.85), 3.0)
    cam = s.camera((0, -46, -4), (0, 0, 0.5), lens=36 if thumb else 52)
    if thumb:
        pilot_objects = hero_pilot((-6.5, -7, -2.6), (0, -10, 0), 1.95, egg_rarity)
    else:
        pilot_objects = hero_pilot((-5.4, -7, -6.4), (0, -10, 0), 2.85, egg_rarity)
    egg_glow(pilot_objects, egg_rarity)
    monster = s.guardian(guardian)
    if guardian.endswith("Whale"):
        s.fit(monster, 36, (10.0 if not thumb else 12, 9, 1.5), (16, 0, -52))
    else:
        s.fit(monster, 32 if not thumb else 24, (7.6 if not thumb else 10, 8, 1.5 if not thumb else 2.5), (10, 0, -42))
    s.point_light((4, 0, 1), (1.0, 0.2, 0.15), 6000, 4)
    lights(key=(-18, -26, 18), rim=(18, 26, 14), power=1.6)
    s.area_light((-20, 8, 20), (-6, -7, -3), (0.5, 0.85, 1.0), 30000, 12)
    inner, outer, centre, nebula, bands = SKIES[sky]
    if thumb:
        # Home, far off behind: where the egg is going.
        s.station((-170, 330, -10), 0.75)
    s.planet((-30, 160, -175), 150, colors=bands)
    s.speed_lines(cam, 60, 14, (0.05, -0.75, 1.0, 0.95), seed=11, alpha=0.55)
    s.backdrop(cam, 400, inner=inner, outer=outer, centre=centre, nebula=nebula, stars=1.4)
    finish(f"{name}-thumb" if thumb else f"{name}-icon")


# --- More thumbnails ---------------------------------------------------------------------------------------

# AlienLooks.TIERS colours (sRGB 0..255), the rarity of each pet in a picture.
TIER_COLORS = [(190, 196, 210), (110, 225, 130), (80, 160, 255), (190, 90, 255), (255, 190, 60)]


def _linear(rgb):
    return tuple((c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4 for c in rgb)


def pet(kind_id, tier, location, size, yaw=0.0):
    """A pet (the game's alien model) of `tier`, its largest side `size`, standing on `location`."""
    import adults
    import robo_kinds

    kind = adults.kind_of(kind_id)
    objects = s.made(lambda: robo_kinds.build(kind, tier, 0, 0))
    s.fit(objects, size, location, (0, 0, yaw))
    return objects


def hatch():
    """What you get: a legendary egg bursting open in the middle, the pets that hatch from eggs
    round it in an arc, each a rarity higher, a glow of its rarity behind each."""
    reset(THUMB)
    bpy.context.scene.view_settings.exposure = -0.1
    s.world((0.55, 0.42, 0.5))
    s.sun((0.35, 0.75, -0.55), (1.0, 0.93, 0.85), 3.0)
    cam = s.camera((0, -44, 6), (0, 0, 1.5), lens=34)
    # The egg in the middle, a burst of light and twinkles round it.
    egg = s.egg("Legendary", halo=0.0, light=0.0)
    s.place(egg, s.pose((0, -8, -1.5), (6, 0, -10), 3.6))
    s.glow_ball((0, 6, -1), 6.5, (1.0, 0.78, 0.3), 5.0, 2.6, 0.85)
    s.point_light((0, -16, 2), (1.0, 0.8, 0.4), 4000, 2)
    for dx, dz, size, turn in ((-5, 6, 2.2, 0.0), (5.5, 4.5, 1.6, 0.4), (4, -5, 1.2, 0.2), (-4.5, -4, 1.0, 0.5)):
        s.sparkle((dx, -12, dz), size, turn=turn)
    # The pets: a common one on the far left to a legendary on the right, growing with rarity.
    lineup = [("slimeWarden", 0, (-19, 4, -7), 8.0, 20), ("crabDrone", 1, (-14, 0, 4), 8.5, 15),
              ("starRay", 3, (13, 0, 5), 11.0, -20), ("devourerSwarm", 2, (-7.5, -6, -5.8), 7.0, 10),
              ("galaxySlime", 4, (17, 2, -6), 11.5, -25)]
    for kind_id, tier, at, size, yaw in lineup:
        pet(kind_id, tier, at, size, yaw)
        s.glow_ball(Vector(at) + Vector((0, 8, 0)), size * 0.5, _linear(TIER_COLORS[tier]), 6.0, 1.8, 0.9)
    lights(key=(-18, -26, 18), rim=(18, 26, 14), power=1.6)
    _, outer, _, nebula, _ = SKIES["violet"]
    s.backdrop(cam, 400, inner=(0.55, 0.4, 0.9), outer=outer, centre=(0.0, 0.0), nebula=nebula, stars=1.4)
    finish("hatch-thumb")


# The zones' top guardians (the last post of each zone), small to huge, and each zone's tint.
ZONE_BOSSES = [
    ("slimeKing", (0.45, 0.75, 0.3)),
    ("wormMother", (0.4, 0.8, 1.0)),
    ("devourerQueen", (1.0, 0.3, 0.3)),
    ("blackRay", (0.55, 0.3, 1.0)),
]


def zones():
    """Further and stronger: the four zones' top guardians in a row, each bigger, in its zone's
    light: from the Debris Belt's Slime King to the Event Horizon's Black Ray."""
    reset(THUMB)
    bpy.context.scene.view_settings.exposure = -0.1
    s.world((0.55, 0.42, 0.5))
    s.sun((0.35, 0.75, -0.55), (1.0, 0.93, 0.85), 3.0)
    cam = s.camera((0, -60, 4), (1, 0, -1), lens=38)
    places = [((-21, 0, -7.5), 9), ((-10, 0, -4), 12.5), ((2.5, 0, -0.5), 16), ((16.5, 4, 1.0), 24)]
    for (kind_id, tint), (at, size) in zip(ZONE_BOSSES, places):
        boss = s.guardian(kind_id)
        # A ray is flat: tilted up towards the camera, or it reads as a line.
        s.fit(boss, size, at, (55, 0, -10) if kind_id.endswith("Ray") else (0, 0, -15))
        s.glow_ball(Vector(at) + Vector((0, size * 0.9, 0)), size * 0.55, tint, 6.0, 1.8, 0.9)
    lights(key=(-18, -36, 18), rim=(18, 40, 14), power=2.2, target=(0, 10, 0))
    s.backdrop(cam, 600, inner=(0.25, 0.4, 0.9), outer=(0.08, 0.02, 0.22), centre=(0.3, 0.3),
               nebula=((0.9, 0.25, 0.8), (0.1, 0.7, 0.95)), stars=1.4)
    finish("zones-thumb")


# --- The community emblem -----------------------------------------------------------------------------------


def emblem():
    """The community's emblem: the legendary egg alone, big in the middle, flying on two jets with
    speed lines behind, twinkles round it. Centred so Roblox's round crop keeps it whole."""
    reset(ICON)
    bpy.context.scene.view_settings.exposure = -0.1
    s.world((0.55, 0.42, 0.5))
    cam = s.camera((0, -30, 0), (0, 0, 0), lens=50)
    egg = s.egg("Legendary", halo=0.0, light=0.0)
    s.place(egg, s.pose((0, -2, 1.4), (6, -14, -12), 4.2))
    for x in (-1.6, 1.6):
        s.flame((x * 0.9 - 1.2, 0, -2.6), (-0.35, 0, -1), length=7.0, radius=0.95)
    s.glow_ball((0, 14, 1.0), 9.0, (1.0, 0.78, 0.3), 5.0, 2.2, 0.9)
    s.point_light((0, -10, 4), (1.0, 0.85, 0.5), 2500, 2)
    for dx, dz, size, turn in ((-6.2, 5.0, 2.0, 0.0), (6.0, 3.6, 1.4, 0.4), (5.2, -4.4, 1.0, 0.2)):
        s.sparkle((dx, -4, dz), size, turn=turn)
    lights(key=(-14, -24, 16), rim=(18, 26, 14), power=1.4)
    s.speed_lines(cam, 40, 10, (-0.9, -0.6, 0.9, 0.9), direction=(0.35, 1.0), seed=5, alpha=0.5)
    s.backdrop(cam, 200, inner=(0.4, 0.3, 0.9), outer=(0.08, 0.02, 0.25), centre=(0.0, 0.0),
               nebula=((0.9, 0.25, 0.8), (0.1, 0.7, 0.95)), stars=1.4)
    finish("emblem")


def pilot_sheet():
    """A check of the pilot with the egg: front, three-quarter back, side and back."""
    reset((2000, 800))
    cam = s.camera((0, -48, 3), (0, 0, 1.5), lens=50)
    for index, yaw in enumerate((0, -125, -90, 180)):
        objects = hero_pilot(((index - 1.5) * 9, 0, 0), (0, 0, 0), 1.0, "Legendary", body_yaw=yaw, head_turn=95 if yaw == -125 else 0)
        del objects
    lights()
    s.backdrop(cam, 80)
    finish("pilot-sheet")


SHOT_BUILDERS = {
    "icon": hero,
    "hero-thumb": lambda: hero(True),
    "hatch": hatch,
    "zones": zones,
    "emblem": emblem,
    "pilot": pilot_sheet,
}

for shot in SHOTS:
    SHOT_BUILDERS[shot]()
