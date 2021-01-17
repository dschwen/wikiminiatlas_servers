#!/bin/bash

db=s51499__wikiminiatlas
server=tools.db.svc.eqiad.wmflabs

mysql -h${server} ${db} < wma_schema.sql
mysql -h${server} ${db} < wma_storedprocedures.sql

for lang in $(cat languages.dat)
do
  echo "CREATE TABLE IF NOT EXISTS page_${lang} (page_id INT(8) PRIMARY KEY, page_title VARBINARY(255), page_len INT(8) UNSIGNED);" | mysql -h${server} ${db}
  echo "CREATE TABLE IF NOT EXISTS coord_${lang} (coord_id INT(8) NOT NULL AUTO_INCREMENT, page_id INT(8), lat FLOAT NOT NULL, lon FLOAT NOT NULL, pop INT(4) NOT NULL, title VARBINARY(255), globe enum('','Mercury','Ariel','Phobos','Deimos','Mars','Rhea','Oberon','Europa','Tethys','Pluto','Miranda','Titania','Phoebe','Enceladus','Venus','Moon','Hyperion','Triton','Ceres','Dione','Titan','Ganymede','Umbriel','Callisto','Jupiter','Io','Earth','Mimas','Iapetus') DEFAULT NULL);" | mysql -h${server} ${db}
done
