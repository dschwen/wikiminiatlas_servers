# Coordinate ectration scripts

## Prerequisite

Install teh `toolforge` python module

```
git clone https://github.com/legoktm/toolforge.git
cd toolforge
python3 setup.py install --user
```

## Hook up label database meta data

Create these two symlinks in the webserver root

```
cd /var/www/wikiminiatlas
ln -s /data/project/wma/wikiminiatlas_servers/maintenance/medians.js
ln -s /data/project/wma/wikiminiatlas_servers/maintenance/master.inc
```
