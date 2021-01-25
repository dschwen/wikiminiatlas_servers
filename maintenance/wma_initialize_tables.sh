#!/bin/bash

db=s51499__wikiminiatlas
server=tools.db.svc.eqiad.wmflabs

mysql -h${server} ${db} < wma_schema.sql
mysql -h${server} ${db} < wma_storedprocedures.sql

for lang in $(cat languages.dat)
do
  echo "CREATE TABLE IF NOT EXISTS page_${lang} (page_id INT(8) PRIMARY KEY, page_title VARBINARY(255), page_len INT(8) UNSIGNED);" | mysql -h${server} ${db}
  echo "CREATE TABLE IF NOT EXISTS coord_${lang} (coord_id INT(8) PRIMARY KEY AUTO_INCREMENT, page_id INT(8), lat FLOAT NOT NULL, lon FLOAT NOT NULL, style TINYINT, weight FLOAT, scale INT(4), title VARBINARY(255), globe SMALLINT UNSIGNED NOT NULL, bad BOOLEAN NOT NULL);" | mysql -h${server} ${db}
  echo "CREATE TABLE IF NOT EXISTS wma_connect_${lang} (id INT(11) PRIMARY KEY AUTO_INCREMENT, tile_id INT(11), label_id INT(11), rev INT(11));" | mysql -h${server} ${db}
  echo "CREATE TABLE IF NOT EXISTS wma_label_${lang} (id INT(11) PRIMARY KEY AUTO_INCREMENT, page_id INT(11), name VARCHAR(255), style INT(11), lat DOUBLE(11,8), lon DOUBLE(11,8), weight INT(11), globe SMALLINT(5) UNSIGNED NOT NULL, KEY `tile_id_index` (`tile_id`));" | mysql -h${server} ${db}
done
