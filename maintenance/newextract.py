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
# page id cache
#
pages_file_name = ".cache/pages_%s.pickle" % lang
try:
    pages_file = open(pages_file_name, "rb")
    pages = pickle.load(pages_file)
    pages_file.close()
except:
    pages = set()

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
    # get data for extracting coordinates
    query = "SELECT page_id, page_title, page_len, SUBSTRING(el_to, POSITION('geohack.php' IN el_to) + 12) AS params "\
            "FROM externallinks, page "\
            "WHERE page_namespace=0 AND page_id >= %d AND page_id < %d AND el_from = page_id AND el_to LIKE '%%geohack.php?%%' "\
            "HAVING LENGTH(params)>8" % (min_page, max_page)

    ccr.execute(query)
    for row in ccr:
        page_id = row[0]
        # new page, insert title into db
        if not page_id in pages:
            with tdb.cursor() as tcr:
                query = 'INSERT INTO page_' + lang + ' (page_id, page_title, page_len) VALUES (%s, %s, %s)'
                try:
                    tcr.execute(query, (page_id, row[1], row[2]))
                    tdb.commit()
                except:
                    # ignore the duplicate primary key integrity error here
                    pass

            pages.add(page_id)
            n_ins += 1

        # process coordinates
        try:
            geo = geolink.parse(row[3].decode('utf-8'), row[1].decode('utf-8').replace('_', ' '), row[2])

            # check if we just inserted this coordinate
            if geo == last_geo:
                n_skip += 1
            else:
                last_geo =  geo.copy()

                with tdb.cursor() as tcr:
                    geo['page_id'] = page_id
                    query = 'INSERT INTO coord_' + lang + ' (page_id, lat, lon, style, weight, scale, title, globe, bad) VALUES (%(page_id)s, %(lat)s, %(lon)s, %(style)s, %(weight)s, %(scale)s, %(title)s, %(globe)s, %(bad)s)'
                    tcr.execute(query, geo)
                    tdb.commit()
        except:
            print("Fail on page '%s': %s" % (row[1].decode('utf-8'), row[3].decode('utf-8')))
            n_fail += 1

        n_tot += 1

        if n_tot % 1000 == 0:
            print("%d rows processed, %d pages inserted, %d coords skipped, %d coords unparsable" % (n_tot, n_ins, n_skip, n_fail))

    min_page += step_page
    max_page += step_page

print("%d rows processed, %d pages inserted, %d coords skipped, %d coords unparsable" % (n_tot, n_ins, n_skip, n_fail))

#
# pickle page id cache
#
pages_file = open(pages_file_name, "wb")
pickle.dump(pages, pages_file)
pages_file.close()
