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

#
# get larget pageid
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

while min_page <= global_max_page:
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
                tcr.execute(query, (page_id, row[1], row[2]))
                tdb.commit()

            pages.add(page_id)
            n_ins += 1

        # process coordinates
        # TODO

        n_tot += 1

        if n_tot % 1000 == 0:
            print("%d rows processed, %d pages inserted" % (n_tot, n_ins))

    min_page += step_page
    max_page += step_page

#
# pickle page id cache
#
pages_file = open(pages_file_name, "wb")
pickle.dump(pages, pages_file)
pages_file.close()
