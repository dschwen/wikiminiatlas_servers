#!/bin/bash

lang=$1
rev=$2

./newextract.py $lang && ./build_qtree_index.py $lang 2 && ./bubble_up_qtree.py $lang $rev && ./set_rev.py $lang $rev && ./update_php_include.py

