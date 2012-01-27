#!/bin/bash

echo $1
REV=`./get_rev.sh $1|sed 's/ //g'`
let REV=$REV+1
./build_qtree_index.pl $1 $REV && ./bubble_up_qtree.pl $1 $REV && ./set_rev.sh $1 $REV

