#!/usr/bin/env python3

import toolforge
import pickle
import sys

#
# get language to process
#
lang = sys.argv[1]
rev = int(sys.argv[2]);

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
# get largest pageid
#
with tdb.cursor() as tcr:
    tcr.execute('SELECT MAX(el_from) FROM externallinks')
    global_max_page = tcr.fetchone()[0];
print("Largest page_id is %d." % global_max_page)

#
# build bad list
#
print('Building badlist...')
bad_list = []
with tdb.cursor() as tcr:
    tcr.execute('SELECT page_id, count(*) AS count FROM coord_sco WHERE bad=1 GROUP BY page_id HAVING count > 5')
    for row in tcr:
        bad_list.append(row[1])
bad_set = set(bad_list)

#
# clear out connectors
#
print('Flushing connectors...')
with tdb.cursor() as tcr:
    query = "DELETE c.*, l.* "\
            "FROM wma_connect c, wma_label l "\
            "WHERE c.label_id = l.id AND c.rev=%(rev)d AND l.lang_id=%(lang_id)d" % {'rev': rev, 'lang_id': lang_id}
    rows = tcr.execute(query)
    print("%d rows deleted" % rows)

# map scale setting
maxzoom = 14;
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
    'lang_id': lang_id,
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
# get coordinates
#
step_page = 20000
min_page = 0
max_page = min_page + step_page

while min_page <= global_max_page:
    query = "SELECT page_id, lat, lon, style, weight, scale, title, globe, t.id "\
            "FROM coord_%(lang)s "\
            "LEFT JOIN wma_tile t "\
            "ON t.z=%(maxzoom)d AND t.x=FLOOR((lon-FLOOR(lon/360)*360) * %(fac)d) AND t.y=FLOOR((lat+90.0) * %(fac)d) " \
            "WHERE lat<=90.0 AND lat>=-90.0" % {'maxzoom': maxzoom, 'fac': fac, 'lang': lang}

    with tdb.cursor() as tcr:
        for row in tcr:
            page_id = row[0]

            # skip coordinates from bad pages
            if page_id in bad_set:
                continue

            tile_id = row[8]

            lat = row[1]
            lon = row[2]
            lon += 360.0 if lon < 0
            if lon < 0.0 or lon > 360.0:
                continue

            with idb.cursor() as icr:
                # tile does not exist yet
                if not tile_id:
                    y = int((90.0 + lat) / 180.0 * ((1 << maxzoom) * 3))
                    x = int( lon / 360.0 * ((1<<maxzoom)*3) * 2 );
                    tile_param['x'] = x
                    tile_param['y'] = y
                    tile_param['xh'] = x // 2
                    tile_param['yh'] = y // 2

                    query = "INSERT INTO wma_tile (x,y,z,xh,yh) VALUES ($(x)s,$(y)s,$(maxzoom)s,$(xh)s,$(yh)s)"
                    icr.execute(query, tile_param)
                    idb.commit()

                    tile_id = icr.lastrowid
                    n_tile += 1

                # now the tile is guaranteed to exist
                label_param['page_id'] = page_id
                label_param['style'] = row[3]
                label_param['weight'] = row[4]
                label_param['name'] = row[6]
                label_param['globe'] = row[7]
                label_param['lat'] = lat
                label_param['lon'] = lon
                label_param['tile_id'] = tile_id

                query = "CALL InsertLabel($(page_id)s, %(lang_id), %(name)s,%(style)s,%(globe)s, %(lat)s,%(lon)s,%(weight)s,%(tile_id)s, %(rev)s)");
                icr.execute(query, label_param)
                idb.commit()


            if n_tot % 1000 == 0:
                print("%d rows processed, %d tile inserted" % (n_tot, n_tile))

        min_page += step_page
        max_page += step_page

print("Done. %d rows processed, %d tile inserted" % (n_tot, n_tile))
