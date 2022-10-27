import geopandas as gp

gp.read_file('land_polygons.shp').simplify(0.0001).to_file('landpoly_simple.shp')
