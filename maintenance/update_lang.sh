#!/bin/bash

# only update languages on a specific database server
IP=`host ${1}wiki.labsdb | cut -d' ' -f4`
if [ $IP = '10.64.37.5' ]
then 
  echo good to go
else
  echo nope
  exit
fi

pushd `dirname $0`
echo $1
REV=`./get_rev.sh $1|sed 's/ //g'`

# clear cut needed after screw up!
REV=0

if [ $REV -lt 20 ]
then
  let REV=$REV+1
  ./build_qtree_index.pl $1 $REV && ./bubble_up_qtree.pl $1 $REV && ./set_rev.sh $1 $REV
else
  echo "Already at rev 1"
fi
popd

