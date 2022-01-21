#!/bin/bash

sudo apt install apache2 libapache2-mod-php php-apcu php-mysql php-pgsql
sudo cp 001-wma.conf /etc/apache2/sites-available/
sudo a2dissite 000-default
sudo a2ensite 001-wma

sudo chown dschwen /var/www
cd /var/www/
git clone ~/wma/wikiminiatlas

sudo systemctl reload apache2

sudo cp ~/replica.my.cnf /var/www/
sudo chown www-data:www-data /var/www/replica.my.cnf
sudo chmod 400 /var/www/replica.my.cnf
