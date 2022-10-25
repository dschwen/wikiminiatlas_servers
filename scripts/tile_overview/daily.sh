#!/bin/bash

# main dir
DIR=/var/www/wikiminiatlas/overview
mkdir -p $DIR
sudo chown www-data:www-data $DIR
sudo chmod 775 $DIR
cd $DIR

# date dir
DIR=$(date '+%Y%m%d')
sudo mkdir $DIR
sudo chown www-data:www-data $DIR

for zoom in 8 9 10 11 12
do
    sudo ~/wma/wikiminiatlas_servers/scripts/tile_overview/render_tile_density.py $zoom
    sudo cp -a overview_${zoom}.png $DIR
    sudo convert overview_${zoom}.png $DIR/overview_${zoom}.gif
    sudo gifsicle */overview_${zoom}.gif -o overview_${zoom}.gif
    sudo chown www-data:www-data overview_${zoom}.*
done

