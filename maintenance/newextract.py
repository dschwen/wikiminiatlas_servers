#!/usr/bin/env python3

#
# WikiMiniAtlas database update script (c) 2009-2021 Daniel Schwen
# Licensed under the GPL3 license
#

import toolforge
import geolink
import pickle
import time
import sys
import os

start_time = time.time()

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
# Open log file
#
log = open(os.path.join(os.path.dirname(__file__), 'logs/log_%s.html' % lang), "w")
log.write("<html><head><meta charset='UTF-8'></head><body><p><a href='/status.php'>back...</a></p>")

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
ccr.execute('SELECT MIN(el_from) FROM externallinks')
global_min_page = ccr.fetchone()[0];
print("page_id are %d - %d." % (global_min_page, global_max_page))
log.write("<p>Found page_id %d - %d.</p>" % (global_min_page, global_max_page))

#
# Weight data for commons images
#
cat_weight = {
  'Featured_pictures_on_Wikimedia_Commons': 50,
  'Quality_images': 10,
  'Valued_images': 5,
  'Self-published_work': 2
}

#
# Get page name, length and geohack link parameter
#
step_page = 20000
min_page = global_min_page
max_page = min_page + step_page
last_geo = None

log.write("<ul>")

while min_page <= global_max_page:
    #  get existing pages from user DB
    with tdb.cursor() as tcr:
        query = 'SELECT page_id, page_title FROM page_' + lang + ' WHERE page_id >= %d AND page_id < %d' % (min_page, max_page)
        tcr.execute(query)
        rows = tcr.fetchall()
    pages = {row[0]: row[1] for row in rows}

    # get data for extracting coordinates
    if lang == 'commons':
        query = "SELECT page_id, page_title, img_size, SUBSTRING(el_to, POSITION('geohack.php' IN el_to) + 12) AS params, img_width, img_height, GROUP_CONCAT( DISTINCT cl_to SEPARATOR '|') "\
                "FROM externallinks, image, page LEFT JOIN categorylinks ON cl_from = page_id "\
                "WHERE page_namespace=6 AND page_id >= %s AND page_id < %s AND img_name = page_title AND el_from = page_id AND el_to LIKE '%%geohack.php?%%' "\
                "GROUP BY page_id "\
                "HAVING LENGTH(params)>8"
    else:
        query = "SELECT page_id, page_title, page_len, SUBSTRING(el_to, POSITION('geohack.php' IN el_to) + 12) AS params "\
                "FROM externallinks, page "\
                "WHERE page_namespace=0 AND page_id >= %s AND page_id < %s AND el_from = page_id AND el_to LIKE '%%geohack.php?%%' "\
                "HAVING LENGTH(params)>8"
    ccr.execute(query, (min_page, max_page))

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

            if lang == 'commons':
                # size in bytes and pixel count
                iw = row[4]
                ih = row[5]
                weight_factor = row[2] ** 0.3 + (iw * ih) ** 0.5

                # slightly penalize extreme aspect ratios
                ar = iw/ih
                if ar < 1:
                    ar = 1 / ar
                if ar > 1.6:
                    weight_factor /= (ar - 0.6)

                # iterate over all categories
                for cat in row[6].decode('utf-8').split('|'):
                    if cat in cat_weight:
                        weight_factor *= cat_weight[cat]

                geo['weight'] = weight_factor
                geo['iw'] = iw
                geo['ih'] = ih

            # check if we just inserted this coordinate
            if geo == last_geo:
                n_skip += 1
            else:
                last_geo = geo.copy()
                if not page_id in coord_dict:
                    coord_dict[page_id] = [geo.copy()]
                else:
                    coord_dict[page_id].append(geo.copy())

        except Exception as e:
            print("Fail on page '%s': %s" % (row[1].decode('utf-8'), row[3].decode('utf-8')))
            log.write("<li><a href='https://%(lang)s.wikipedia.org/wiki/%(page)s'>%(page)s</a> : %(link)s<br/>%(except)s</li>" % {'lang': lang, 'page': row[1].decode('utf-8').replace("'","&#39;"), 'link': row[3].decode('utf-8'), 'except': str(e)})
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
        if lang == 'commons':
            query = 'INSERT INTO coord_commons (page_id, lat, lon, style, weight, scale, title, globe, bad, heading, iw, ih) VALUES (%(page_id)s, %(lat)s, %(lon)s, %(style)s, %(weight)s, %(scale)s, %(title)s, %(globe)s, %(bad)s, %(heading)s, %(iw)s, %(ih)s)'
        else:
            query = 'INSERT INTO coord_' + lang + ' (page_id, lat, lon, style, weight, scale, title, globe, bad) VALUES (%(page_id)s, %(lat)s, %(lon)s, %(style)s, %(weight)s, %(scale)s, %(title)s, %(globe)s, %(bad)s)'
        tcr.executemany(query, coord_batch)
        tdb.commit()


    min_page += step_page
    max_page += step_page

print("Done. %d rows processed, %d pages inserted, %d coords skipped, %d coords unparsable" % (n_tot, n_ins, n_skip, n_fail))

stop_time = time.time()

#
# Close log
#
log.write("</ul>")
log.write("<p>%d rows processed<br/>%d pages inserted<br/>%d coords skipped<br/>%d coords unparsable<br/>%d seconds.</p>" % (n_tot, n_ins, n_skip, n_fail, int(stop_time-start_time)))
log.write("</body></html>")
log.close()
