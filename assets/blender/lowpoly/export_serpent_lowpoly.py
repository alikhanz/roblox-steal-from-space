# Exports the star serpent's kit in the faceted low-poly style (decision 119): the serpent's own
# builder (assets/blender/serpent/serpent_kit.py) with its shapes cut coarse and flat-shaded. Same
# pieces, names, specks, colours and layout, so the game (World/SerpentVisual) takes it unchanged:
#   ball -> an ico sphere (80 faces; 20 for the small ones: eyes, the jet's glow);
#   ring -> 16 x 4 (12 x 4 for the small ones);
#   cone, rod -> at most 8 sides, flat;
#   everything flat-shaded (the facets are the style).
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/lowpoly/export_serpent_lowpoly.py -- <outdir> [--sheet]

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "serpent"))

import bpy  # noqa: E402
import serpent_kit as kit  # noqa: E402


def flat(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def ball(location, radii, rgb, rotation=(0, 0, 0), segs=kit.SEGS, rings=kit.RINGS):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2 if segs >= 16 else 1, radius=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = radii
    return kit.paint(flat(obj), rgb)


def ring(location, major, minor, rgb, axis, segments=28, sides=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=16 if segments >= 24 else 12,
                                     minor_segments=4, location=location, rotation=kit.turn_to(axis))
    return kit.paint(flat(bpy.context.active_object), rgb)


_cone, _rod = kit.cone, kit.rod


def cone(base, tip, r1, rgb, r2=0.0, vertices=8):
    return _cone(base, tip, r1, rgb, r2=r2, vertices=min(vertices, 8))


def rod(a, b, radius, rgb, vertices=8):
    return _rod(a, b, radius, rgb, vertices=min(vertices, 8))


kit.smooth = flat
kit.ball = ball
kit.ring = ring
kit.cone = cone
kit.rod = rod

if __name__ == "__main__":
    kit.main()
