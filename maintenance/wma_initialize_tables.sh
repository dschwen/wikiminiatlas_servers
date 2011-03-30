#!/bin/bash

for c in `seq 1 7`
do
  mysql -hsql-s${c}-user.toolserver.org -e "CREATE DATABASE IF NOT EXISTS u_dschwen;"
  mysql -hsql-s${c}-user.toolserver.org u_dschwen < wma_tile.schema.sql
  mysql -hsql-s${c}-user.toolserver.org u_dschwen < wma_connect.schema.sql
  mysql -hsql-s${c}-user.toolserver.org u_dschwen < wma_label.schema.sql
  mysql -hsql-s${c}-user.toolserver.org u_dschwen < wma_storedprocedures.sql
done

