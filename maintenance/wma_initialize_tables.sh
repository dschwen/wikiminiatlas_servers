#!/bin/bash

db=s51499__wikiminiatlas
server=tools.db.svc.eqiad.wmflabs

mysql -h${server} ${db} < wma_schema.sql
mysql -h${server} ${db} < wma_storedprocedures.sql

for lang in $(cat languages.dat)
do
  echo "CREATE TABLE IF NOT EXISTS page_${lang} (page_id INT(8) PRIMARY KEY, page_title VARBINARY(255), page_len INT(8) UNSIGNED);" | mysql -h${server} ${db}
done
