# SHP files

Low resolution tiles are rendered from Natural Earth shapefiles. Intermediate resolution coastlines are using a simplified land polygons data from OSM.

Use the `./update_cache.sh` script to refresh the local copies of teh OSM and Natural Earth data.

## Prerequisites

Install geopandas for reading and simplifying shapefiles.

```
pip install --user geopandas
```

### Update land polygons for 9-12 zoom level

Download and unzip [`land-polygons-split-4326.zip`](https://osmdata.openstreetmap.de/download/land-polygons-split-4326.zip) at 

https://osmdata.openstreetmap.de/data/land-polygons.html

and run `simplify.py`

