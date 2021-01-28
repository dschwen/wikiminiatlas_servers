#!/usr/bin/env python3

#
# WikiMiniAtlas database update script (c) 2009-2021 Daniel Schwen
# Licensed under the GPL3 license
#

import pickle
import sys
import os

#
# languages
#
lang_path = os.path.join(os.path.dirname(__file__), 'languages.dat')
with open(lang_path) as lang_file:
    lang_list = [i.rstrip('\n') for i in lang_file.readlines()]

#
# get language to process
#
lang = sys.argv[1]
rev = int(sys.argv[2])
if not lang in lang_list:
    print("Language not found. Add it to the bottom of the %s file first.")
    sys.exit(1)

#
# load rev id cache
#
rev_path = os.path.join(os.path.dirname(__file__), 'rev.pickle')
try:
    rev_file = open(rev_path, "rb")
    rev_dict = pickle.load(rev_file)
    rev_file.close()
except:
    rev_dict = {lang: 1 for lang in lang_list}

#
# modify revision
#
rev_dict[lang] = rev

#
# load rev id cache
#
rev_file = open(rev_path, "wb")
pickle.dump(rev_dict, rev_file)
rev_file.close()

