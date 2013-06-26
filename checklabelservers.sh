#!/bin/bash

PATH=$PATH:/opt/ts/gnu/bin/

LOCK=/home/dschwen/wma/.checklabelserv.lock.`hostname`

if [ 1000 -lt $(($(date +%s) - $(stat -c '%Y' "$LOCK"))) ]
then
  echo stale lockfile found, deleting
  rm $LOCK
fi

if [ ! -s $LOCK ]
then
	echo $$ > $LOCK

	#
	# find and kill old php processes
	#

	for pid in `ps -u dschwen -o"pid comm" | awk '{ if( $2 == "/opt/php/bin/php-cgi" ) print $1 }'`
	do 
		if [ /proc/$pid/auxv -ot .lastrun ]
		then 
			kill $pid 
		fi
	done
	touch .lastrun

	#
	# Check if tile generators are running
	#

	for zoom in 8 9 10 11 12
	do
	  TGFIL="/tmp/wikiminiatlas.tile${zoom}.pid"
	  TGEXE='none'
	  if [ -e $TGFIL ]
	  then
	    TGPID=`cat /tmp/wikiminiatlas.tile${zoom}.pid`
	    TGEXE=`pargs ${TGPID} | head -n1 | cut -f2 | cut -d' ' -f1`
	  fi
	  if [ "$TGEXE" = "/home/dschwen/wma/programs/mapniktile/mapniktile3" ]
	  then
	    date > /tmp/wikiminiatlas.lastchecked
	  else
            date
	    echo starting tileserver for zoom $zoom
	    pushd /home/dschwen/public_html/wma/tiles
	    nohup /home/dschwen/wma/programs/mapniktile/mapniktile3 $zoom > /home/dschwen/wma/log/mapnik.log.$zoom.`hostname` &
	    popd
	  fi
	done

        #
        # new satellite data fetcher/scaler
        #

        TGFIL="/tmp/wikiminiatlas.sat.pid"
        TGEXE='none'
	if [ -e $TGFIL ]
	then
	  TGPID=`cat /tmp/wikiminiatlas.sat.pid`
	  TGEXE=`pargs ${TGPID} | head -n1 | cut -f2 | cut -d' ' -f1`
	fi
	if [ "$TGEXE" = "/home/dschwen/wma/programs/satscaler/satscale" ]
	then
	  date > /tmp/wikiminiatlas.lastchecked
	else
          date
	  echo starting satellite rescaling tileserver
	  pushd /home/dschwen/public_html/wma/tiles
	  nohup /home/dschwen/wma/programs/satscaler/satscale > /home/dschwen/wma/log/mapnik.sat.log.`hostname` &
	  popd
	fi

	: > $LOCK
else
	echo lockfile found.
fi

