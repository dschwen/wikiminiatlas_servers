#!/usr/bin/env python3

#
# WikiMiniAtlas database update script (c) 2009-2021 Daniel Schwen
# Licensed under the GPL3 license
#

import pickle
import sys
import os

#
# globes
#
with open(os.path.join(os.path.dirname(__file__), 'globes.dat')) as globes_file:
    globes_list = [i.rstrip('\n') for i in globes_file.readlines()]

#
# languages
#
with open(os.path.join(os.path.dirname(__file__), 'languages.dat')) as lang_file:
    lang_list = [i.rstrip('\n') for i in lang_file.readlines()]
lang = {lang_list[i].lower(): i for i in range(len(lang_list))}

#
# rev id cache
#
rev_path = os.path.join(os.path.dirname(__file__), 'rev.pickle')
try:
    rev_file = open(rev_path, "rb")
    rev_dict = pickle.load(rev_file)
    rev_file.close()
except:
    rev_dict = {lang: 1 for lang in lang_list}

#
# write master PHP include
#
with open(os.path.join(os.path.dirname(__file__), 'master.inc'), "w") as inc_file:
    inc_file.write("<?php\n")

    # globes
    inc_file.write("$globes = array(")
    inc_file.write(", ".join(["'%s'=>%d" % (globes_list[i].lower(), i) for i in range(len(globes_list))]))
    inc_file.write(");\n")

    # languages
    inc_file.write("$langs = array(")
    inc_file.write(", ".join(["'%s'=>%d" % (lang_list[i].lower(), i) for i in range(len(lang_list))]))
    inc_file.write(");\n")

    # revisions
    inc_file.write("$lrev = array(")
    inc_file.write(", ".join(["'%s'=>%d" % (lang, rev) for lang, rev in rev_dict.items()]))
    inc_file.write(");\n")

    inc_file.write("?>\n")
