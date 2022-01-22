#!/usr/bin/env python3

import pyvips
import sys

img = pyvips.Image.new_from_file(sys.argv[1])
w = img.width
h = img.height
max_z = int(math.ceil(math.log2(img.height/(3*256))))
