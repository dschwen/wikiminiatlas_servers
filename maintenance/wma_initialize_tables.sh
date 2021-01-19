#!/bin/bash

db=s51499__wikiminiatlas
server=tools.db.svc.eqiad.wmflabs

mysql -h${server} ${db} < wma_schema.sql
mysql -h${server} ${db} < wma_storedprocedures.sql

for lang in $(cat languages.dat)
do
  echo "CREATE TABLE IF NOT EXISTS page_${lang} (page_id INT(8) PRIMARY KEY, page_title VARBINARY(255), page_len INT(8) UNSIGNED);" | mysql -h${server} ${db}
  echo "DROP TABLE coord_${lang}; CREATE TABLE IF NOT EXISTS coord_${lang} (coord_id INT(8) PRIMARY KEY AUTO_INCREMENT, page_id INT(8), lat FLOAT NOT NULL, lon FLOAT NOT NULL, style TINYINT, weight FLOAT, scale INT(4), title VARBINARY(255), globe SMALLINT UNSIGNED NOT NULL, bad BOOLEAN NOT NULL);" | mysql -h${server} ${db}
done
