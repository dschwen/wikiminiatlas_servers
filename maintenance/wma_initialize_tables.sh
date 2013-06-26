#!/bin/bash

#  `seq 1 7`
for c in 2
do
  server=hap-s$c-user.esi.toolserver.org
  echo server $server
  mysql -h${server} -e "CREATE DATABASE IF NOT EXISTS u_dschwen;"
  mysql -h${server} u_dschwen < wma_schema.sql
  #mysql -h${server} u_dschwen < wma2_schema.sql
  #mysql -h${server} u_dschwen < wma2_storedprocedures.sql
  mysql -h${server} u_dschwen < wma_storedprocedures.sql
  #mysql -hsql-s${c}-user.toolserver.org u_dschwen -e "ALTER TABLE wma_label ADD COLUMN globe enum('','Mercury','Ariel','Phobos','Deimos','Mars','Rhea','Oberon','Europa','Tethys','Pluto','Miranda','Titania','Phoebe','Enceladus','Venus','Moon','Hyperion','Triton','Ceres','Dione','Titan','Ganymede','Umbriel','Callisto','Jupiter','Io','Earth','Mimas','Iapetus');"
 # mysql -hsql-s${c}-user.toolserver.org u_dschwen -e "ALTER TABLE wma_label CHANGE lat lat DOUBLE(11,8);"
 # mysql -hsql-s${c}-user.toolserver.org u_dschwen -e "ALTER TABLE wma_label CHANGE lon lon DOUBLE(11,8);"
  #mysql -hsql-s${c}-user.toolserver.org u_dschwen -e "UPDATE wma_label SET globe='Earth';";
done

#mysql -hcommonswiki-p.userdb.toolserver.org u_dschwen < wma_tile.schema.sql
#mysql -hcommonswiki-p.userdb.toolserver.org u_dschwen < wma_connect.schema.sql
#mysql -hcommonswiki-p.userdb.toolserver.org u_dschwen < wma_label.schema.sql
#mysql -hcommonswiki-p.userdb.toolserver.org u_dschwen < wma_storedprocedures.sql
#mysql -hcommonswiki-p.userdb.toolserver.org u_dschwen -e "ALTER TABLE wma_label ADD COLUMN globe enum('','Mercury','Ariel','Phobos','Deimos','Mars','Rhea','Oberon','Europa','Tethys','Pluto','Miranda','Titania','Phoebe','Enceladus','Venus','Moon','Hyperion','Triton','Ceres','Dione','Titan','Ganymede','Umbriel','Callisto','Jupiter','Io','Earth','Mimas','Iapetus');"
