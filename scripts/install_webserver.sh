#!/bin/bash

sudo apt install apache2 libapache2-mod-php
sudo cp 001-wma.conf /etc/apache2/sites-available/
sudo a2dissite 000-default
sudo a2ensite 001-wma

sudo chown dschwen /var/www
cd /var/www/
git clone ~/wma/wikiminiatlas

sudo systemctl reload apache2
