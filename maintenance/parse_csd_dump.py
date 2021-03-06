#!/usr/bin/env python3

#
# WikiMiniAtlas commons structured data dump extraction script (c) 2021 Daniel Schwen
# Licensed under the GPL3 license
#

import re
import sys
import time
import toolforge

#
# connect to database
#
tdb = toolforge.toolsdb('s51499__wikiminiatlas')

#
# clear table
#
with tdb.cursor() as tcr:
    tcr.execute("DELETE FROM coord_commons_structured_data")
    tdb.commit()

#
# regular expressions for parsing data
#
line_re = re.compile(".*entity/statement/M(\d+)-.*www\.wikidata\.org/prop/[^/]+/P([\d]+)>\s*\"([^\"]+)\".*")
coord_re = re.compile("Point\(([^\s]+) ([^)]+)\)")

#
# write batch of images to database
#
n_total = 0
def writeBatch(batch):
    # don't do anything on empty batches
    if not batch:
        return

    query = "INSERT INTO coord_commons_structured_data "\
            "(page_id, camera_lat, camera_lon, object_lat, object_lon) VALUES "\
            "(%(page_id)s, %(camera_lat)s, %(camera_lon)s, %(object_lat)s, %(object_lon)s)"

    with tdb.cursor() as tcr:
        tcr.executemany(query, batch)
        tdb.commit()

    global n_total, start_time
    now = time.time()
    n_total += len(batch)
    print("%d items written. (%.2f items/s)" % (n_total, n_total/(now-start_time)))

#
# parse coordinate data
#
def namedCoord(name):
    def coord(v):
        match = coord_re.match(v)
        return {name+'_lat': float(match.group(1)), name+'_lon': float(match.group(2))}
    return coord

#
# valid properties and how to parse them
#
p_dir = {
    '625': namedCoord('object'),
    '1259': namedCoord('camera'),
    '7787': lambda v: {'heading': float(v)}
}

#
# set up initial state for batched data extraction
#
last_m = None
batch = []
image = {}

start_time = time.time()

#
# loop over standard input lines
#
for line in sys.stdin:
    # is the line of interest?
    match = line_re.match(line)
    if match and match.group(2) in p_dir:
        # convert data
        m = int(match.group(1))
        val = p_dir[match.group(2)](match.group(3))

        # is this a new image?
        if m != last_m:
            # add previous image to batch
            if image:
                batch.append(image)

            # write images to db if we have gathered enough
            if len(batch) == 1000:
                writeBatch(batch)
                batch = []

            # create new image item
            image = {'page_id': m, 'camera_lat': None, 'camera_lon': None, 'object_lat': None, 'object_lon': None, 'heading': None}
            last_m = m

        # add data to current image item
        image.update(val)

# write remaining images
if image:
    batch.append(image)
writeBatch(batch)

stop_time = time.time()
print("Done. %d s elapsed." % int(stop_time-start_time))
