#!/bin/bash

echo $1 updated on `date` >> update_lang.log

pushd ~/public_html/wma
cp rev.inc .oldrev/rev.inc.`date +%s`
./setrev.pl $1 $2 > rev.inc.new
mv rev.inc.new rev.inc
popd
