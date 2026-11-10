# A readability check for the game page's icons: each icon as Roblox shows it on a phone (about
# 150 px in the home feed and the search) and on a PC (about 250 px), side by side on a dark
# strip, and the 512 px file Roblox takes. Also turns a 1024 render into the 512 upload.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/store/preview_sizes.py -- <out.png> <icon.png> ...
#   blender --background --factory-startup --python assets/blender/store/preview_sizes.py -- --resize <size> <in.png> <out.png>

import os
import sys

import bpy
import numpy

ARGS = sys.argv[sys.argv.index("--") + 1:]
SIZES = (150, 250)
GAP = 24


def load(path):
    image = bpy.data.images.load(path)
    image.colorspace_settings.name = "sRGB"
    return image


def scaled(path, size):
    image = load(path)
    copy = image.copy()
    copy.scale(size, size)
    return numpy.array(copy.pixels[:], dtype=numpy.float32).reshape(size, size, 4)


def save(pixels, path):
    height, width = pixels.shape[:2]
    result = bpy.data.images.new("Out", width, height, alpha=True)
    result.pixels = pixels.ravel()
    # Absolute: Blender reads a relative path from the .blend file, not the working folder.
    result.filepath_raw = os.path.abspath(path)
    result.file_format = "PNG"
    result.save()
    print("Wrote", path)


if ARGS[0] == "--resize":
    size, source, target = int(ARGS[1]), ARGS[2], ARGS[3]
    save(scaled(source, size), target)
else:
    out, icons = ARGS[0], ARGS[1:]
    width = GAP + len(icons) * (sum(SIZES) + GAP * len(SIZES))
    height = max(SIZES) + 2 * GAP
    strip = numpy.zeros((height, width, 4), dtype=numpy.float32)
    strip[:, :] = (0.07, 0.075, 0.09, 1.0)  # Roblox's dark theme
    x = GAP
    for path in icons:
        for size in SIZES:
            pixels = scaled(path, size)
            # Blender images start at the bottom: align the icons' bottoms.
            strip[GAP:GAP + size, x:x + size] = pixels
            x += size + GAP
    save(strip, out)
