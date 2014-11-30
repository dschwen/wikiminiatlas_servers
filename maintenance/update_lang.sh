#!/bin/bash

pushd `dirname $0`
echo $1
REV=`./get_rev.sh $1|sed 's/ //g'`
if [ $REV -lt 2 ]
then
  let REV=$REV+1
  ./build_qtree_index.pl $1 $REV && ./bubble_up_qtree.pl $1 $REV && ./set_rev.sh $1 $REV
else
  echo "Already at rev 1"
fi
popd

