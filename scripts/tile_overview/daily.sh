#!/bin/bash

DIR=/var/www/wikiminiatlas/overview
mkdir -p $DIR
sudo chown www-data:www-data $DIR
sudo chmod 775 $DIR
cd $DIR

for zoom in 8 9 10 11 12
do
    sudo ~/wma/wikiminiatlas_servers/scripts/tile_overview/render_tile_density.py $zoom
done

DIR=$(date '+%Y%m%d')
sudo mkdir $DIR
sudo cp -a overview_*.png $DIR
sudo chown www-data:www-data $DIR
