#!/usr/bin/env python3

#
# WikiMiniAtlas suspicious coordinates script (c) 2021 Daniel Schwen
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

lang_list = ['commons']

for lang in lang_list:
    sus_path = os.path.join(os.path.dirname(__file__), 'logs/sus_%s.html' % lang)
    sus_file = open(sus_path, "w")
    sus_file.write('<html><head><title>%s</title></head><body><ul>\n' % lang)
    with tdb.cursor() as tcr:
        query = 'select title, lat, lon from coord_' + lang + ' where lat % 10 = 0 or lon % 10 = 0'
        tcr.execute(query)
        for row in tcr.fetchall():
            title = row[0].decode('utf-8').split('|')
            if title[0][-4:] == '.svg' or 'geograph.org.uk' in title[0]:
                continue
            sus_file.write("<li><a href='https://commons.wikimedia.org/wiki/File:%s'>%s</a> at %.2f,%.2f image %s x %s px, head %s</li>\n" % (title[0].replace("'","&#39;"), title[0], row[1], row[2], title[1], title[2], title[3]))

    sus_file.write('</ul></body></html>')
    sus_file.close()
