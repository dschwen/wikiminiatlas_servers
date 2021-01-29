#!/usr/bin/env python3

#
# WikiMiniAtlas commons structured data dump extraction script (c) 2021 Daniel Schwen
# Licensed under the GPL3 license
#

import re
import sys

# regular expressions for parsing data
line_re = re.compile(".*entity/statement/M(\d+)-.*www\.wikidata\.org/prop/[^/]+/P([\d]+)>\s*\"([^\"]+)\".*")
coord_re = re.compile("Point\(([^\s]+) ([^)]+)\)")

# parse coordinate data
def namedCoord(name):
    def coord(v):
        match = coord_re.match(v)
        return {name+'_lat': float(match.group(1)), name+'_lon': float(match.group(2))}
    return coord

# write bunch of images to database
def writeBunch(bunch):
    # don't do anything on empty bunches
    if not bunch:
        return
    print(bunch)

# valid properties
p_dir = {
    '625': namedCoord('object'),
    '1259': namedCoord('camera'),
    '7787': lambda v: {'heading': float(v)}
}

# set up initial state for bunched data extraction
last_m = None
bunch = []
image = {}

# loop over standard input lines
for line in sys.stdin:
    # is the line of interest?
    match = line_re.match(line)
    if match and match.group(2) in p_dir:
        # convert data
        m = int(match.group(1))
        p_name = p_dir[match.group(2)][0]
        val = p_dir[match.group(2)][1](match.group(3))

        # is this a new image?
        if m != last_m:

            # write images to db if we have gathered enough
            if len(bunch) == 10:
                writeBunch(bunch)
                bunch = []

            if image:
                bunch.append(image)
            image = {'page_id': m}
            last_m = m

        # add data to current image item
        image.update(val)

# write remaining images
if image:
    bunch.append(image)
writeBunch(bunch)
