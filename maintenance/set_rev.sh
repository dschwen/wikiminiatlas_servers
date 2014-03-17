#!/bin/bash

echo $1 updated on `date` >> update_lang.log

WEB=/var/www/wikiminiatlas
BAK=/data/project/wma/bak

cp $WEB/rev.inc $BAK/oldrev/rev.inc.`date +%s`
./setrev.pl $1 $2 $WEB/rev.inc > rev.inc.new && sudo cp rev.inc.new $WEB/rev.inc

mv rev.inc.new $BAK
