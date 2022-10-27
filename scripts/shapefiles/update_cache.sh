#!/bin/bash

for uri in $(cat uris.txt)
do
  pushd cache/
  
  echo $uri
  
  file=${uri##*/}
  ref=${uri%/*}
  
  echo $file
  echo $ref

  if test -e "$file"
    then zflag="-z $file"
    else zflag=
  fi
  curl -L -o "$file" $zflag "$uri"

  unzip -u $file

  popd
done
