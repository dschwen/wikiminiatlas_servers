#!/bin/bash

WEB=/var/www/wikiminiatlas
grep '^"'$1'" =>' $WEB/rev.inc | cut -d'>' -f2 | cut -d, -f1
