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

# load languages list
with open(os.path.join(os.path.dirname(__file__), 'languages.dat')) as lang_file:
    lang_id = [i.rstrip('\n') for i in lang_file.readlines()].index(lang)

print("Processing %s (%d) wiki. Revison %d." % (lang, lang_id, rev))

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
    global_max_coord = tcr.fetchone()[0]
    tcr.execute('SELECT MIN(coord_id) FROM coord_' + lang)
    global_min_coord = tcr.fetchone()[0]
print("Found coord_id %d - %d." % (global_min_coord, global_max_coord))

#
# build bad list
#
print('Building badlist...')
bad_list = []
with tdb.cursor() as tcr:
    tcr.execute('SELECT page_id, count(*) AS count FROM coord_' + lang + ' WHERE bad=1 GROUP BY page_id HAVING count > 5')
    for row in tcr:
        bad_list.append(row[0])
bad_set = set(bad_list)

#
# clear out connectors
#
print('Flushing connectors...')
with tdb.cursor() as tcr:
    query = "DELETE c.*, l.* "\
            "FROM wma_connect_%(lang)s c, wma_label_%(lang)s l "\
            "WHERE c.label_id = l.id AND c.rev=%(rev)d" % {'rev': rev, 'lang': lang}
    rows = tcr.execute(query)
    print("%d rows deleted" % rows)
    tdb.commit()

# map scale setting
maxzoom = 14
fac = ((1 << maxzoom) * 3) / 180.0

tile_param = {
    'x': None,
    'y': None,
    'z': maxzoom,
    'xh': None,
    'yh': None
}

label_param = {
    'page_id': None,
    'name': None,
    'style': None,
    'globe': None,
    'lat': None,
    'lon': None,
    'weight': None,
    'tile_id': None,
    'rev': rev
}

#
# get tile list
#
print('Fetching tilelist...')
tile_list = {}
with tdb.cursor() as tcr:
    tcr.execute('SELECT id, x, y FROM wma_tile WHERE z=%s', maxzoom)
    for row in tcr:
        tile_list[(row[1], row[2])] = row[0]
print("%d tiles found." % len(tile_list.keys()))

#
# get coordinates
#
step_coord = 20000
min_coord = global_min_coord
max_coord = min_coord + step_coord

while min_coord <= global_max_coord:
    query = "SELECT page_id, lat, lon, style, weight, scale, title, globe, bad "\
            "FROM coord_" + lang + " "\
            "WHERE coord_id >= %(min_coord)s AND coord_id < %(max_coord)s AND lat<=90.0 AND lat>=-90.0"

    with tdb.cursor() as tcr:
        tcr.execute(query, {'min_coord': min_coord, 'max_coord': max_coord, 'maxzoom': maxzoom, 'fac': fac})
        rows = tcr.fetchall()

    print("%d rows retireved." % len(rows))

    label_batch = []
    for row in rows:
        page_id = row[0]
        bad = row[8]

        # skip coordinates from bad pages
        if bad and page_id in bad_set:
            continue

        lat = row[1]
        lon = row[2]
        if lon < 0:
            lon += 360.0 
        if lon < 0.0 or lon > 360.0:
            continue

        y = int((90.0 + lat) / 180.0 * ((1 << maxzoom) * 3))
        x = int(lon / 360.0 * ((1 << maxzoom) * 3) * 2)
        
        # tile does not exist yet
        if not (x,y) in tile_list:
            tile_param['x'] = x
            tile_param['y'] = y
            tile_param['xh'] = x // 2
            tile_param['yh'] = y // 2

            with idb.cursor() as icr:
                query = "INSERT INTO wma_tile (x,y,z,xh,yh) VALUES (%(x)s,%(y)s,%(z)s,%(xh)s,%(yh)s)"
                icr.execute(query, tile_param)
                label_param['tile_id'] = icr.lastrowid
                idb.commit()

            n_tile += 1
        else:
            label_param['tile_id'] = tile_list[(x,y)]
            

        # now the tile is guaranteed to exist
        label_param['page_id'] = page_id
        label_param['style'] = row[3]
        label_param['weight'] = row[4]
        label_param['name'] = row[6]
        label_param['globe'] = row[7]
        label_param['lat'] = lat
        label_param['lon'] = lon

        # add label to batch 
        label_batch.append(label_param.copy())
        n_tot += 1

        # status update
        if n_tot % 1000 == 0:
            print("%d rows processed, %d tile inserted" % (n_tot, n_tile))

    # insert batch of labels
    print("Inserting batch...")
    with idb.cursor() as icr:
        query = "CALL InsertLabel_" + lang + "(%(page_id)s, %(name)s, %(style)s, %(globe)s, %(lat)s, %(lon)s, %(weight)s, %(tile_id)s, %(rev)s)"
        icr.executemany(query, label_batch)
        idb.commit()

    min_coord += step_coord
    max_coord += step_coord


print("Done. %d rows processed, %d tile inserted" % (n_tot, n_tile))
