# Tiles PNG renders into one contact sheet (rows of equal-size images), for comparing shots.
# Run headless:
#   blender --background --factory-startup --python assets/blender/lib/sheet.py -- <out.png> <columns> <in1.png> <in2.png> ...

import sys

import bpy
import numpy

args = sys.argv[sys.argv.index("--") + 1 :]
out, columns, inputs = args[0], int(args[1]), args[2:]
images = [bpy.data.images.load(path) for path in inputs]
width, height = images[0].size
rows = (len(images) + columns - 1) // columns
sheet = numpy.zeros((rows * height, columns * width, 4), dtype=numpy.float32)
for index, image in enumerate(images):
    pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(height, width, 4)
    row, column = divmod(index, columns)
    # Blender images start at the bottom row.
    top = (rows - 1 - row) * height
    sheet[top : top + height, column * width : (column + 1) * width] = pixels
result = bpy.data.images.new("Sheet", columns * width, rows * height, alpha=True)
result.pixels = sheet.ravel()
result.filepath_raw = out
result.file_format = "PNG"
result.save()
print("Wrote", out)
