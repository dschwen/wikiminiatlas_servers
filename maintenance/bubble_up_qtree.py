#!/usr/bin/env python3

import toolforge
import pickle
import sys
import os

#
# get language to process
#
lang = sys.argv[1]
rev = int(sys.argv[2])

# load languages list (just verify it is in the list)
with open(os.path.join(os.path.dirname(__file__), 'languages.dat')) as lang_file:
    if not lang in [i.rstrip('\n') for i in lang_file.readlines()]:
        print("Unknown language")
        sys.exit(1)

print("Processing %s wiki. Revison %d." % (lang, rev))

#
# Connect to database (tdb for reading, idb for tile insertion)
#
tdb = toolforge.toolsdb('s51499__wikiminiatlas')
idb = toolforge.toolsdb('s51499__wikiminiatlas')

n_tot = 0
n_tile = 0

#
# get largest coord_id
#
with tdb.cursor() as tcr:
    tcr.execute('SELECT MAX(coord_id) FROM coord_' + lang)
    global_max_coord = tcr.fetchone()[0];
    tcr.execute('SELECT MIN(coord_id) FROM coord_' + lang)
    global_min_coord = tcr.fetchone()[0];
print("Found coord_id %d - %d." % (global_min_coord, global_max_coord))


# iterate over zoom levels
maxzoom = 14
for zoom in range(maxzoom - 1, -1, -1):
    print("Zoom level %d..." % zoom)

    zoompo = zoom + 1

    query = "DELETE QUICK c.* "\
            "FROM wma_connect_" + lang + " c, wma_label_" + lang + " l, wma_tile t "\
            "WHERE c.label_id = l.id AND c.tile_id=t.id AND c.rev=%(rev)s "\
            "AND t.z=%(zoom)s"

    with tdb.cursor() as tcr:
        rows = tcr.execute(query, {'rev': rev, 'zoom': zoom})
        print("%d connectors deleted" % rows)
        tdb.commit()

    query = "INSERT INTO wma_tile (x,y,z,xh,yh) "\
            "SELECT DISTINCT  t.xh, t.yh, %(zoom)s, FLOOR(t.xh/2), FLOOR(t.yh/2) "\
            "FROM wma_tile t "\
            "LEFT JOIN wma_tile t2 ON t2.x=t.xh AND t2.y=t.yh AND t2.z=%(zoom)s "\
            "WHERE t.z=%(zoompo)s AND t2.id IS NULL"

    with tdb.cursor() as tcr:
        rows = tcr.execute(query, {'zoom': zoom, 'zoompo': zoompo})
        print("%d missing tiles inserted" % rows)
        tdb.commit()


    query = "INSERT INTO wma_connect_" + lang + " (tile_id,label_id,rev) "\
            "SELECT tileid, label_id, %(rev)s "\
            "FROM ( "\
            "    SELECT c.tile_id AS tid, c.label_id, t2.id AS tileid, l.globe "\
            "    FROM wma_connect_" + lang + " c, wma_label_" + lang + " l, wma_tile t, wma_tile t2 "\
            "    WHERE t.id = c.tile_id AND l.id = c.label_id AND t.z=%(zoompo)s AND c.rev=%(rev)s "\
            "    AND t2.z=%(zoom)s AND t2.x=t.xh AND t2.y=t.yh "\
            "    ORDER BY t.id,l.globe,l.weight DESC"\
            ") AS low_level_tiles "\
            "GROUP BY tid, globe"

    with tdb.cursor() as tcr:
        tcr.execute(query, {'rev': rev, 'zoom': zoom, 'zoompo': zoompo})
        tdb.commit()
