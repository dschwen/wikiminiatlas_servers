#!/usr/bin/env python3

#
# WikiMiniAtlas median lable weight script (c) 2021 Daniel Schwen
# Licensed under the GPL3 license
#

import toolforge
import json
import os

#
# Connect to databases
#
tdb = toolforge.toolsdb('s51499__wikiminiatlas')

#
# iterate over all languages
#
lang_path = os.path.join(os.path.dirname(__file__), 'languages.dat')
with open(lang_path) as lang_file:
    lang_list = [i.rstrip('\n') for i in lang_file.readlines()]

medians = {}
for lang in lang_list:
    levels = []

    # For zoom levels 0-8 we suppress all labels with a weight below the median
    for z in range(9):
        with tdb.cursor() as tcr:
            query = 'select count(*) from wma_connect_' + lang + ' c, wma_label_' + lang + ' l, wma_tile t WHERE l.id=c.label_id AND c.tile_id=t.id AND z=%s'
            tcr.execute(query, z)
            rows = [i[0] for i in tcr.fetchall()]

        # sort list
        rows.sort()

        # pick median
        median = rows[len(rows) // 2]
        levels.append(median)

    medians[lang] = levels

#
# write
#
median_path = os.path.join(os.path.dirname(__file__), 'medians.js')
median_file = open(median_path, "w")
median_file.write('var wma_median_weights = ')
median_file.write(json.dumps(medians))
median_file.write(';')
median_file.close()
