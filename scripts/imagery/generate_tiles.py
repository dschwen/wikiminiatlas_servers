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
img = pyvips.Image.new_from_file(sys.argv[1])
iw = img.width
ih = img.height
max_z = int(math.ceil(math.log2(ih/(3*ts))))

print("Rescaling...")
h = (1 << max_z) * 3 * ts
w = 2 * h
img = img.thumbnail_image(w, height=h)

print("Tiling...")
img.dzsave(sys.argv[2], tile_size=ts, overlap=0, depth='onetile', layout='google')
