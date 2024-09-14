#!/usr/bin/env python3

import sys

if len(sys.argv) != 3 :
    print("usage:", sys.argv[0], 'input_image output_prefix')
    sys.exit(1)

import pyvips
import math

# tile size
ts = 256

print("Opening...")

# single image
#img = pyvips.Image.new_from_file(sys.argv[1])

# image pair
#img1 = pyvips.Image.new_from_file(sys.argv[1] % 'west')
#img2 = pyvips.Image.new_from_file(sys.argv[1] % 'east')
#img = img1.join(img2, "horizontal")

# Global Image Grid (A1-D2)
img = None
for row_index in ['1', '2'] :
  row = None
  for col_index in ['A', 'B', 'C', 'D'] :
    tile = pyvips.Image.new_from_file(sys.argv[1] % (col_index + row_index))
    row = tile if not row else row.join(tile, "horizontal")
  img = row if not img else img.join(row, "vertical")

iw = img.width
ih = img.height
max_z = int(math.ceil(math.log2(ih/(3*ts))))

print("Rescaling...")
h = (1 << max_z) * 3 * ts
w = 2 * h
img = img.thumbnail_image(w, height=h)

print("Tiling...")
img.dzsave(sys.argv[2], tile_size=ts, overlap=0, depth='onetile', layout='google')
