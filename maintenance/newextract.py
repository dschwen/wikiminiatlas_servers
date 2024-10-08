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
sleep = 5

log.write("<ul>")

while min_page <= global_max_page:
    #  get existing pages from user DB (not for commons)
    try:
        if lang != 'commons':
            with tdb.cursor() as tcr:
                query = 'SELECT page_id, page_title FROM page_' + lang + ' WHERE page_id >= %d AND page_id < %d' % (min_page, max_page)
                tcr.execute(query)
                rows = tcr.fetchall()
            pages = {row[0]: row[1] for row in rows}

        # get data for extracting coordinates
        if lang == 'commons':
            query = "SELECT page_id, page_title, img_size, SUBSTRING(el_to_path, POSITION('geohack.php' IN el_to_path) + 12) AS params, img_width, img_height, GROUP_CONCAT( DISTINCT cl_to SEPARATOR '|') "\
                    "FROM externallinks, image, page LEFT JOIN categorylinks ON cl_from = page_id "\
                    "WHERE page_namespace=6 AND page_id >= %s AND page_id < %s AND img_name = page_title AND el_from = page_id AND el_to_path LIKE '%%geohack.php?%%' "\
                    "GROUP BY page_id "\
                    "HAVING LENGTH(params)>8"
        else:
            query = "SELECT page_id, page_title, page_len, SUBSTRING(el_to_path, POSITION('geohack.php' IN el_to_path) + 12) AS params "\
                    "FROM externallinks, page "\
                    "WHERE page_namespace=0 AND page_id >= %s AND page_id < %s AND el_from = page_id AND el_to_path LIKE '%%geohack.php?%%' "\
                    "HAVING LENGTH(params)>8"
        ccr.execute(query, (min_page, max_page))
        sleep = 5
    except Exception as e:
        sleep *= 2
        print("Query failed, retrying in %d s..." % sleep)
        print(str(e))
        log.write("<li>Query failure, retrying in %d s... <!-- %s --></li>" % (sleep, str(e)))
        time.sleep(sleep)
        continue

    page_batch = []
    coord_dict = {}

    for row in ccr:
        page_id = row[0]
        page_title = row[1]

        # do not maintain page_commons, as the labels contain the full file name already
        if lang != 'commons':
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

                # image size and heading are coded into the label text string for commons
                geo['title'] = page_title.decode('utf-8') + '|' + str(iw) + '|' + str(ih) + '|'

                # encode the heading (18 means no heading info)
                if geo['heading'] is not None:
                    heading =  int(( (int(geo['heading']) + 360) % 360 ) / 22.5 + 0.5) % 16
                    geo['title'] += str(heading)
                    # heading gives a 20% score boost
                    weight_factor *= 1.2
                else:
                    # no heading
                    geo['title'] += '18'

                # style = -2 cause thumbnails to be displayed at half size
                if iw*ih < 1024**2:
                    geo['style'] = -2
                else:
                    geo['style'] = -1

                geo['weight'] = int(weight_factor)

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
            print(str(e))
            log.write("<li><a href='https://%(lang)s.wikipedia.org/wiki/%(page)s'>%(page)s</a> : %(link)s<br/>%(except)s</li>" % {'lang': lang, 'page': row[1].decode('utf-8').replace("'","&#39;"), 'link': row[3].decode('utf-8'), 'except': str(e)})
            n_fail += 1

        n_tot += 1

        if n_tot % 1000 == 0:
            now = time.time()
            print("%d rows processed, %d pages inserted, %d coords skipped, %d coords unparsable. %.2f items/s" % (n_tot, n_ins, n_skip, n_fail, n_tot/(now-start_time) ))

    # batch insert pages
    if lang != 'commons':
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
    if lang == 'commons':
        for c in coord_dict.values():
            # keep only one coordinate, preferably type:camera
            found = False
            for i in c:
                if i['type'] == 'camera':
                    coord_batch.append(i)
                    found = True
                    break
            if not found:
                for i in c:
                    if i['type'] == 'object':
                        coord_batch.append(i)
                        break
    else:
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

stop_time = time.time()

#
# Close log
#
log.write("</ul>")
log.write("<p>%d rows processed<br/>%d pages inserted<br/>%d coords skipped<br/>%d coords unparsable<br/>%d seconds.</p>" % (n_tot, n_ins, n_skip, n_fail, int(stop_time-start_time)))
log.write("</body></html>")
log.close()
