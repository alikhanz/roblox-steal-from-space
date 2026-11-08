# The lava crack texture for a meteor pet's molten shell in game (the renders draw the cracks with a
# procedural Voronoi, which glTF and Roblox cannot carry). Two seamless 512px tiles:
#   lava_color.png: dark cooled crust, mottled, with orange lava in the cracks and a yellow-hot core;
#   lava_glow.png:  the emissive mask, white along the cracks (SurfaceAppearance.EmissiveMaskContent).
# Seamless: the Voronoi cells wrap round the tile's edges. The export (export_robo_roblox.py) gives the
# molten parts box-projected UVs at the same scale, so the cracks are one size all over a pet.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/aliens/lava_texture.py -- <outdir>

import os
import sys

import bpy
import numpy as np

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "build/icons")
SIZE = 512
CELLS = 26
# Crack width, as a share of the gap between neighbour cells' distances (F2 - F1).
CRACK = 0.022
WARP = 0.05
CRUST_DARK = np.array([0.025, 0.016, 0.013])
CRUST_LIGHT = np.array([0.075, 0.048, 0.036])
LAVA = np.array([1.0, 0.33, 0.04])
HOT = np.array([1.0, 0.85, 0.35])


def voronoi_edges(rng):
    """The distance from each pixel to the edge of its wrapping Voronoi cell, doubled: the edge is the
    bisector between the nearest and second-nearest seeds (F2 - F1 would swell into wedges where two
    seeds sit close)."""
    points = rng.random((CELLS, 2))
    copies = np.concatenate([points + np.array([dx, dy]) for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    axis = (np.arange(SIZE) + 0.5) / SIZE
    x, y = np.meshgrid(axis, axis)
    # Wobble the cracks: shift the lookup by seamless noise, so the edges bend instead of running straight.
    x = x + WARP * (wrapping_noise(rng, 8) - 0.5)
    y = y + WARP * (wrapping_noise(rng, 8) - 0.5)
    d2 = (x[..., None] - copies[:, 0]) ** 2 + (y[..., None] - copies[:, 1]) ** 2
    nearest = np.argpartition(d2, 1, axis=-1)[..., :2]
    first = np.take_along_axis(d2, nearest[..., :1], -1)[..., 0]
    second = np.take_along_axis(d2, nearest[..., 1:2], -1)[..., 0]
    swap = first > second
    first, second = np.where(swap, second, first), np.where(swap, first, second)
    a, b = copies[nearest[..., 0]], copies[nearest[..., 1]]
    gap = np.sqrt(((a - b) ** 2).sum(-1))
    return (second - first) / gap


def wrapping_noise(rng, waves):
    """Smooth seamless noise: a sum of sine waves with whole periods across the tile."""
    axis = np.arange(SIZE) / SIZE
    x, y = np.meshgrid(axis, axis)
    total = np.zeros((SIZE, SIZE))
    for _ in range(waves):
        kx, ky = rng.integers(1, 7, 2) * rng.choice([-1, 1], 2)
        total += np.sin(np.pi * 2 * (kx * x + ky * y) + rng.random() * np.pi * 2)
    return (total / waves + 1) / 2


def save(name, rgb):
    image = bpy.data.images.new(name, SIZE, SIZE, alpha=True)
    rgba = np.ones((SIZE, SIZE, 4))
    rgba[..., :3] = np.clip(rgb, 0, 1)
    # Blender's pixels run bottom to top.
    image.pixels.foreach_set(rgba[::-1].ravel().astype(np.float32))
    image.filepath_raw = os.path.join(OUT_DIR, name + ".png")
    image.file_format = "PNG"
    image.save()
    print("Wrote", image.filepath_raw)


def main():
    rng = np.random.default_rng(11)
    edge = voronoi_edges(rng)
    # Cracks vary in width along their length.
    width = CRACK * (0.6 + 0.8 * wrapping_noise(rng, 6))
    heat = np.clip(1 - edge / width, 0, 1)
    heat = heat ** 2.2
    core = np.clip(1 - edge / (width * 0.35), 0, 1)
    mottle = wrapping_noise(rng, 10)[..., None]
    crust = CRUST_DARK + (CRUST_LIGHT - CRUST_DARK) * mottle
    lava = LAVA + (HOT - LAVA) * core[..., None]
    halo_glow = np.clip(1 - edge / (width * 3.5), 0, 1) ** 2 * 0.3
    crust = crust + (LAVA * 0.35 - crust) * halo_glow[..., None]
    colour = crust + (lava - crust) * heat[..., None]
    # sRGB for the PNG (the colours above are linear, as in the Blender material).
    save("lava_color", np.where(colour <= 0.0031308, colour * 12.92, 1.055 * colour ** (1 / 2.4) - 0.055))
    # The mask: the crack itself and a faint glow beside it.
    halo = np.clip(1 - edge / (width * 3.5), 0, 1) ** 2 * 0.25
    mask = np.repeat(np.maximum(heat, halo)[..., None], 3, axis=2)
    save("lava_glow", mask)


main()
