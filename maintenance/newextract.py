#!/usr/bin/env python3

#
# WikiMiniAtlas database update script (c) 2009-2021 Daniel Schwen
# Licensed under the GPL3 license
#

import toolforge
import geolink
import pickle
import sys

#
# get language to process
#
try:
    lang = sys.argv[1]
except:
    lang = 'en'

print("Processing %s wiki." % lang)

#
# Connect to databases
#
cdb = toolforge.connect(lang + 'wiki')
tdb = toolforge.toolsdb('s51499__wikiminiatlas')

ccr = cdb.cursor()

n_tot = 0
n_ins = 0
n_skip = 0
n_fail = 0

#
# clear out the temporary coordinates table
#
with tdb.cursor() as tcr:
    tcr.execute("DELETE FROM coord_%s" % lang)
    tdb.commit()
    tcr.execute("ALTER TABLE coord_%s AUTO_INCREMENT = 1" % lang)
    tdb.commit()

#
# get largest pageid
#
ccr.execute('SELECT MAX(el_from) FROM externallinks')
global_max_page = ccr.fetchone()[0];
print("Largest page_id is %d." % global_max_page)

#
# Get page name, length and geohack link parameter
#
step_page = 20000
min_page = 0
max_page = min_page + step_page
last_geo = None

while min_page <= global_max_page:
    #  get existing pages from user DB
    with tdb.cursor() as tcr:
        query = 'SELECT page_id, page_title FROM page_' + lang + ' WHERE page_id >= %d AND page_id < %d' % (min_page, max_page)
        tcr.execute(query)
        rows = tcr.fetchall()
    pages = {row[0]: row[1] for row in rows}

    # get data for extracting coordinates
    query = "SELECT page_id, page_title, page_len, SUBSTRING(el_to, POSITION('geohack.php' IN el_to) + 12) AS params "\
            "FROM externallinks, page "\
            "WHERE page_namespace=0 AND page_id >= %d AND page_id < %d AND el_from = page_id AND el_to LIKE '%%geohack.php?%%' "\
            "HAVING LENGTH(params)>8" % (min_page, max_page)
    ccr.execute(query)

    page_batch = []
    coord_dict = {}

    for row in ccr:
        page_id = row[0]
        page_title = row[1]

        if page_id in pages and pages[page_id] != page_title:
            # page exits but was renamed. delete old entry db row
            print("Warning: Page was renamed '%s' -> '%s'!" % (pages[page_id], page_title))

            with tdb.cursor() as tcr:
                tcr.execute("DELETE FROM page_%s WHERE page_id=%d" % (lang, page_id))
                tdb.commit()

            # delete dict entry to trigger batch insert below
            del pages[page_id]

        if not page_id in pages:
            # new page, insert title into db
            page_batch.append((page_id, page_title, row[2]))
            pages[page_id] = page_title
            n_ins += 1

        # process coordinates
        try:
            geo = geolink.parse(row[3].decode('utf-8'), page_title.decode('utf-8').replace('_', ' '), row[2])
            geo['page_id'] = page_id

            # check if we just inserted this coordinate
            if geo == last_geo:
                n_skip += 1
            else:
                last_geo = geo.copy()
                if not page_id in coord_dict:
                    coord_dict[page_id] = [geo.copy()]
                else:
                    coord_dict[page_id].append(geo.copy())

        except:
            print("Fail on page '%s': %s" % (row[1].decode('utf-8'), row[3].decode('utf-8')))
            n_fail += 1

        n_tot += 1

        if n_tot % 1000 == 0:
            print("%d rows processed, %d pages inserted, %d coords skipped, %d coords unparsable" % (n_tot, n_ins, n_skip, n_fail))

    # batch insert pages
    with tdb.cursor() as tcr:
        query = 'INSERT INTO page_' + lang + ' (page_id, page_title, page_len) VALUES (%s, %s, %s)'
        try:
            tcr.executemany(query, page_batch)
            tdb.commit()
        except:
            # ignore the duplicate primary key integrity error here
            pass

    # process coords to insert
    coord_batch = []
    for c in coord_dict.values():
        for i in c:
            # the weight of each coordinate is divided by the number of coordinates on the same page
            i['weight'] //= len(c)
        coord_batch += c

    # batch insert coords
    with tdb.cursor() as tcr:
        geo['page_id'] = page_id
        query = 'INSERT INTO coord_' + lang + ' (page_id, lat, lon, style, weight, scale, title, globe, bad) VALUES (%(page_id)s, %(lat)s, %(lon)s, %(style)s, %(weight)s, %(scale)s, %(title)s, %(globe)s, %(bad)s)'
        tcr.executemany(query, coord_batch)
        tdb.commit()


    min_page += step_page
    max_page += step_page

print("Done. %d rows processed, %d pages inserted, %d coords skipped, %d coords unparsable" % (n_tot, n_ins, n_skip, n_fail))
