/*****************************************************************************
 * 
 * mapniktile.cc - Generates maptiles for the WikiMiniAtlas
 *
 * (c) 2007 by Daniel Schwen (dschwen)
 *
 * This file is based on an example for Mapnik (c++ mapping toolkit)
 * Copyright (C) 2006 Artem Pavlenko
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 *****************************************************************************/
// $Id$

#include <mapnik/map.hpp>
#include <mapnik/color.hpp>
#include <mapnik/datasource_cache.hpp>
#include <mapnik/font_engine_freetype.hpp>
#include <mapnik/proj_transform.hpp>
#include <mapnik/agg_renderer.hpp>
#include <mapnik/filter_factory.hpp>
#include <mapnik/color_factory.hpp>
#include <mapnik/image_util.hpp>

#include <iostream>

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

//#define DEBUGPOSTGIS
#ifdef LINUX
#include <linux/stat.h>
#endif

const unsigned int sleep_max = 1000;
unsigned int sleep_t = 0;

using namespace mapnik;

void registerLayer( Layer* l, int minzoom ) {
}

int main ( int argc , char** argv)
{    
    std::cout << argc << "\n";
    int zoom = 6;
    if( argc == 5 || argc == 2 ) zoom = atoi(argv[1]);

    double thickfac = 1.0;
    if ( zoom >= 6 && zoom < 12 ) thickfac = 1.5 / ( 12.0 - double(zoom) );

    datasource_cache::instance()->register_datasources("/opt/ts/mapnik/0.7.1-gcc/lib/mapnik/input"); 
    freetype_engine::register_font("/opt/ts/share/fonts/DejaVuSans.ttf");
    
    Map m(128,128);

    // (1.0,1.0,0.816) land = 
    // (0.62,0.78,0.953) water =

    //m.setBackground(color_factory::from_string("white"));
    if( zoom >= 8 ) {
      // bg is oceans, land is plotted
      m.set_background( color(158, 199, 243) );
    }  else {
      // bg is land, oceans are plotted
      m.set_background( color(250, 250, 208) );
    }

    //
    // create styles
    //

    // Water (polygon)
    feature_type_style waterpoly_style;
    rule_type waterpoly_rule;
    waterpoly_rule.append(polygon_symbolizer(color(158, 199, 243)));
    waterpoly_rule.append(line_symbolizer(color(158, 199, 243)));
    waterpoly_style.add_rule(waterpoly_rule);
    m.insert_style("ocean",waterpoly_style);
    
    // Coastline (polygon)
    feature_type_style coastline_style;
    rule_type coastline_rule;
    //stroke coastline_stroke(color(142, 179, 219)); // (158, 199, 243)*0.9
    stroke coastline_stroke(color(0, 0, 255)); // (158, 199, 243)*0.9
    coastline_stroke.set_opacity(0.05);
    coastline_rule.append(line_symbolizer(coastline_stroke));
    coastline_style.add_rule(coastline_rule);
    m.insert_style("coast",coastline_style);
 
    /*
    // Coastline
    feature_type_style coast_style;
    rule_type coast_rule;
    coast_rule.append(line_symbolizer(color(126, 159, 194),0.1));
    coast_style.add_rule(coast_rule);
    m.insert_style("coast",coast_style);
    */

    // Swamp (polygon)
    feature_type_style swamppoly_style;
    rule_type swamppoly_rule;
    swamppoly_rule.append(polygon_symbolizer(color(204, 224, 225))); 
    swamppoly_rule.append(line_symbolizer(color(204, 224, 225)));
    swamppoly_style.add_rule(swamppoly_rule);
    m.insert_style("swamp",swamppoly_style);

    feature_type_style swamp2poly_style;
    rule_type swamp2poly_rule;
    swamp2poly_rule.set_filter(create_filter("[natural] = 'wetland'"));
    swamp2poly_rule.append(polygon_symbolizer(color(204, 224, 225))); 
    swamp2poly_rule.append(line_symbolizer(color(204, 224, 225)));
    swamp2poly_style.add_rule(swamp2poly_rule);
    m.insert_style("swamp2",swamp2poly_style);


    // Nationalpark (polygon)
    feature_type_style nps_style;
    rule_type nps_rule;
    polygon_symbolizer nps_fill(color(0, 150, 0));
    nps_fill.set_opacity(0.2);
    nps_rule.append(nps_fill);
    nps_style.add_rule(nps_rule);
    m.insert_style("usnps",nps_style);


    // Landmass (polygon)
    feature_type_style landpoly_style;
    rule_type landpoly_rule;
    landpoly_rule.append(polygon_symbolizer(color(250, 250, 208)));
    landpoly_style.add_rule(landpoly_rule);
    m.insert_style("landmass",landpoly_style);


    // Lakes (polygon)
    feature_type_style lakepoly_style;
    rule_type lakepoly_rule;
    lakepoly_rule.set_filter(create_filter("[hyc] = 8 and [f_code] = 'BH000'"));
    lakepoly_rule.append(polygon_symbolizer(color(158, 199, 243)));
    lakepoly_style.add_rule(lakepoly_rule);
    m.insert_style("lakes",lakepoly_style);

    feature_type_style lake2poly_style;
    rule_type lake2poly_rule;
    lake2poly_rule.set_filter(create_filter("[waterway] = 'riverbank' or [waterway] = 'dock' or [natural] = 'bay' or [natural] = 'water'"));
    lake2poly_rule.append(polygon_symbolizer(color(158, 199, 243)));
    //lake2poly_rule.append(line_symbolizer(color(58, 99, 243)));
    lake2poly_style.add_rule(lake2poly_rule);
    m.insert_style("lakes2",lake2poly_style);


    // Grassland (polygon)
    feature_type_style grasspoly_style;
    rule_type grasspoly_rule;
    grasspoly_rule.append(polygon_symbolizer(color(208, 250, 208)));
    grasspoly_style.add_rule(grasspoly_rule);
    m.insert_style("grassland",grasspoly_style);

    feature_type_style grass2poly_style;
    rule_type grass2poly_rule;
    grass2poly_rule.set_filter(create_filter("[natural] = 'grassland' or [natural] = 'fell'"));
    grass2poly_rule.append(polygon_symbolizer(color(208, 250, 208)));
    grass2poly_style.add_rule(grass2poly_rule);
    m.insert_style("grass2",grass2poly_style);


    // Trees (polygon)
    feature_type_style treepoly_style;
    rule_type treepoly_rule;
    treepoly_rule.append(polygon_symbolizer(color(190, 240, 190)));
    treepoly_style.add_rule(treepoly_rule);
    m.insert_style("trees",treepoly_style);

    feature_type_style tree2poly_style;
    rule_type tree2poly_rule;
    tree2poly_rule.set_filter(create_filter("[natural] = 'wood'"));
    tree2poly_rule.append(polygon_symbolizer(color(190, 240, 190)));
    tree2poly_style.add_rule(tree2poly_rule);
    m.insert_style("trees2",tree2poly_style);


    // Landice (polygon)
    feature_type_style landice_style;
    rule_type landice_rule;
    landice_rule.append(polygon_symbolizer(color(255, 255, 255)));
    landice_style.add_rule(landice_rule);
    m.insert_style("landice",landice_style);


    // Seaice (shelf) (polygon)
    feature_type_style seaice_style;
    rule_type seaice_rule;
    seaice_rule.set_filter(create_filter("[f_code] = 'BJ065'"));
    seaice_rule.append(polygon_symbolizer(color(207, 227, 249)));
    seaice_style.add_rule(seaice_rule);
    m.insert_style("seaice",seaice_style);

    // Seaice (pack) (polygon)
    feature_type_style seaice_style2;
    rule_type seaice_rule2;
    seaice_rule2.set_filter(create_filter("[f_code] = 'BJ070'"));
    seaice_rule2.append(polygon_symbolizer(color(182, 213, 246)));
    seaice_style2.add_rule(seaice_rule2);
    m.insert_style("seaice2",seaice_style);


    // Builtup (polygon)
    feature_type_style builtup_style;
    rule_type builtup_rule;
    //qcdrain_rule.set_filter(create_filter("[HYC] = 8"));
    builtup_rule.append(polygon_symbolizer(color(208, 208, 208)));
    builtup_style.add_rule(builtup_rule);
    m.insert_style("builtup",builtup_style);

    // 'military','railway','commercial','industrial','residential,'retail','basin','salt_pond','orchard','cemetary','meadow','village_green','forrest'
    feature_type_style builtup2_style;
    rule_type builtup2_rule;
    builtup2_rule.set_filter(create_filter("[landuse] = 'residential' or [landuse] = 'retail' or [landuse] = 'commercial' or [landuse] = 'industrial'"));
    builtup2_rule.append(polygon_symbolizer(color(208, 208, 208)));
    builtup2_style.add_rule(builtup2_rule);
    m.insert_style("builtup2",builtup2_style);

    feature_type_style offlimits_style;
    rule_type offlimits_rule;
    offlimits_rule.set_filter(create_filter("[landuse] = 'military' or [landuse] = 'railway'"));
    offlimits_rule.append(polygon_symbolizer(color(224, 200, 200)));
    offlimits_style.add_rule(offlimits_rule);
    m.insert_style("offlimits",offlimits_style);

    feature_type_style greenuse_style;
    rule_type greenuse_rule;
    greenuse_rule.set_filter(create_filter("[landuse] = 'orchard' or [landuse] = 'cemetary' or [landuse] = 'meadow' or [landuse] = 'village_green' or [landuse] = 'forrest' or [landuse] = 'recreation_ground' or [leisure] = 'dog_park' or [leisure] = 'garden' or [leisure] = 'park' or [leisure] = 'pitch' or [leisure] = 'stadium'"));
    greenuse_rule.append(polygon_symbolizer(color(200, 224, 200)));
    greenuse_style.add_rule(greenuse_rule);
    m.insert_style("greenuse",greenuse_style);

    feature_type_style blueuse_style;
    rule_type blueuse_rule;
    blueuse_rule.set_filter(create_filter("[landuse] = 'basin' or [landuse] = 'salt_pond'"));
    blueuse_rule.append(polygon_symbolizer(color(200, 200, 224 )));
    blueuse_style.add_rule(blueuse_rule);
    m.insert_style("blueuse",blueuse_style);

    // Canals (polygon)
    feature_type_style canal_style;
    rule_type canal_rule;
    canal_rule.set_filter(create_filter("[waterway] = 'canal'"));
    canal_rule.append(line_symbolizer(color(158, 199, 243), 2.0 ));
    canal_style.add_rule(canal_rule);
    m.insert_style("canal",canal_style);

    // Waterways (polygon)
    feature_type_style waterway_style;
    rule_type waterway_rule;
    waterway_rule.set_filter(create_filter("[waterway] = 'river'"));
    waterway_rule.append(line_symbolizer(color(126, 159, 194)));
    waterway_style.add_rule(waterway_rule);
    m.insert_style("waterway",waterway_style);

    // intermittent Waterways (polygon)
    feature_type_style iwaterway_style;
    rule_type iwaterway_rule;
    stroke iwaterway_stk (color(126, 159, 194),1.0);
    iwaterway_stk.add_dash(2, 2);
    iwaterway_rule.set_filter(create_filter("[waterway] = 'stream'"));
    iwaterway_rule.append(line_symbolizer(iwaterway_stk));
    iwaterway_style.add_rule(iwaterway_rule);
    m.insert_style("iwaterway",iwaterway_style);

/*
    // Misc structure (dam etc.) (polyline)
    feature_type_style dam_style;
    rule_type dam_rule;
    dam_rule.append(line_symbolizer(color(125, 125, 125),3.0));
    dam_style.add_rule(dam_rule);
    m.insert_style("dam",dam_style);
*/


    // Ferry
    feature_type_style ferry_style;
    rule_type ferry_rule;
    //ferry_rule.set_filter(create_filter("[route] = 'ferry'"));
    stroke ferry_stk( color(126, 159, 194),2.0 );
    ferry_stk.add_dash(4, 4);
    ferry_rule.append(ferry_stk);
    ferry_style.add_rule(ferry_rule);
    m.insert_style("ferry",ferry_style);


    // Bridge/Causeway
    feature_type_style causeway_style;
    rule_type causeway_rule;
    causeway_rule.set_filter(create_filter("[f_code] = 'AQ064' and [tuc] = 3"));
    causeway_rule.append(line_symbolizer(color(126, 159, 194),5.0));
    causeway_rule.append(line_symbolizer(color(255, 255, 255),3.0));
    causeway_style.add_rule(causeway_rule);
    m.insert_style("causeway",causeway_style);


    // Borders (polyline)
    feature_type_style border1_style;
    /*stroke border1_stk (Color(0,0,0),0.5);
    border1_stk.add_dash(8, 4);
    border1_stk.add_dash(2, 2);
    border1_stk.add_dash(2, 2);*/
    rule_type border1_rule;
    border1_rule.set_filter(create_filter("[use] = 23"));
    //border1_rule.append(line_symbolizer(border1_stk));
    border1_rule.append(line_symbolizer(color(108,108,108),0.5));
    border1_style.add_rule(border1_rule);
    m.insert_style("border1",border1_style);

    // Borders regional (polyline)
    feature_type_style border2_style;
    rule_type border2_rule;
    border2_rule.set_filter(create_filter("[use] = 26"));
    border2_rule.append(line_symbolizer(color(108,108,108),0.15));
    border2_style.add_rule(border2_rule);
    m.insert_style("border2",border2_style);


    // Railroads (polyline)
    feature_type_style raillines_style;
    rule_type raillines_rule;
    raillines_rule.set_filter(create_filter("[railway] = 'rail'"));
    stroke raillines_stk( color(255,255,255), 1.0 );
    raillines_stk.add_dash(3, 3);
    raillines_rule.append(line_symbolizer( color(100,100,100), 2.0) );
    raillines_rule.append( line_symbolizer( raillines_stk ) );
    raillines_style.add_rule(raillines_rule);
    m.insert_style("raillines",raillines_style);

    // Preserved rail
    feature_type_style raillines2_style;
    rule_type raillines2_rule;
    raillines2_rule.set_filter(create_filter("[railway] = 'preserved'"));
    raillines2_rule.append(line_symbolizer( color(200,200,200), 2.0) );
    raillines2_rule.append( line_symbolizer( raillines_stk ) );
    raillines2_style.add_rule(raillines2_rule);
    m.insert_style("raillines2",raillines2_style);


    // Railroadbridge (polyline)
    feature_type_style raillines_bridge_style;
    rule_type raillines_bridge_rule;
    raillines_bridge_rule.set_filter(create_filter("[f_code] = 'AQ064' and [tuc] = 4"));
    raillines_bridge_rule.append(line_symbolizer( color(126, 159, 194), 2.0) );
    raillines_bridge_rule.append( line_symbolizer( raillines_stk ) );
    raillines_bridge_style.add_rule(raillines_bridge_rule);
    m.insert_style("raillines-bridge",raillines_bridge_style);


    //
    // Unpaved (The grey ones)
    //
    feature_type_style roads3_style_1;
    rule_type roads3_rule_1;
    stroke roads3_rule_stk_1(color(168,168,168),2.0*thickfac);
    roads3_rule_stk_1.set_line_cap(ROUND_CAP);
    roads3_rule_stk_1.set_line_join(ROUND_JOIN);
    roads3_rule_1.append(line_symbolizer(roads3_rule_stk_1));
    roads3_style_1.add_rule(roads3_rule_1);
    m.insert_style("grayroad-border", roads3_style_1);
    
    feature_type_style roads3_style_2;
    rule_type roads3_rule_2;
    stroke roads3_rule_stk_2(color(208,208,208),1.0*thickfac);
    roads3_rule_stk_2.set_line_cap(ROUND_CAP);
    roads3_rule_stk_2.set_line_join(ROUND_JOIN);
    roads3_rule_2.append(line_symbolizer(roads3_rule_stk_2));
    roads3_style_2.add_rule(roads3_rule_2);
    m.insert_style("grayroad-fill", roads3_style_2);

    //
    // Residential  (The thin white ones)
    //
    feature_type_style trails_style_1;
    rule_type trails_rule_1;
    stroke trails_rule_stk_1(color(200,200,200),3.5*thickfac);
    trails_rule_stk_1.set_line_cap(ROUND_CAP);
    trails_rule_stk_1.set_line_join(ROUND_JOIN);
    trails_rule_1.append(line_symbolizer( trails_rule_stk_1));
    trails_style_1.add_rule( trails_rule_1);
    m.insert_style("trail-border", trails_style_1);
    
    feature_type_style trails_style_2;
    rule_type trails_rule_2;
    stroke trails_rule_stk_2(color(255,255,255),1.5*thickfac);
    trails_rule_stk_2.set_line_cap(ROUND_CAP);
    trails_rule_stk_2.set_line_join(ROUND_JOIN);
    trails_rule_2.append(line_symbolizer(trails_rule_stk_2));
    trails_style_2.add_rule(trails_rule_2);
    m.insert_style("trail-fill", trails_style_2);
    
    //
    // Roads 2 (The thin yellow ones)
    //
    feature_type_style roads2_style_1;
    rule_type roads2_rule_1;
    stroke roads2_rule_stk_1(color(171,158,137),4.5*thickfac);
    roads2_rule_stk_1.set_line_cap(ROUND_CAP);
    roads2_rule_stk_1.set_line_join(ROUND_JOIN);
    roads2_rule_1.append(line_symbolizer(roads2_rule_stk_1));
    roads2_style_1.add_rule(roads2_rule_1);
    m.insert_style("road-border", roads2_style_1);
    
    feature_type_style roads2_style_2;
    rule_type roads2_rule_2;
    stroke roads2_rule_stk_2(color(255,250,115),2.5*thickfac);
    roads2_rule_stk_2.set_line_cap(ROUND_CAP);
    roads2_rule_stk_2.set_line_join(ROUND_JOIN);
    roads2_rule_2.append(line_symbolizer(roads2_rule_stk_2));
    roads2_style_2.add_rule(roads2_rule_2);
    m.insert_style("road-fill", roads2_style_2);

    //
    // Roads 1 (The big orange ones, the highways)
    //
    feature_type_style roads1_style_1;
    rule_type roads1_rule_1;
    stroke roads1_rule_stk_1(color(188,149,28),4.5*thickfac);
    roads1_rule_stk_1.set_line_cap(ROUND_CAP);
    roads1_rule_stk_1.set_line_join(ROUND_JOIN);
    roads1_rule_1.append(line_symbolizer(roads1_rule_stk_1));
    roads1_style_1.add_rule(roads1_rule_1);
    m.insert_style("highway-border", roads1_style_1);

    feature_type_style roads1_style_2;
    rule_type roads1_rule_2;
    stroke roads1_rule_stk_2(color(242,191,36),2.5*thickfac);
    roads1_rule_stk_2.set_line_cap(ROUND_CAP);
    roads1_rule_stk_2.set_line_join(ROUND_JOIN);
    roads1_rule_2.append(line_symbolizer(roads1_rule_stk_2));
    roads1_style_2.add_rule(roads1_rule_2);
    m.insert_style("highway-fill", roads1_style_2);


    // Layers (Water/Land base)
    if( zoom < 8 ) {
        // Water  polygons
        parameters p;
        p["type"]="shape";
        p["file"]="shp/oceansea";
        
        Layer lyr("Ocean"); 
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("ocean");    
        m.addLayer(lyr);
    }  
    else {
        // Coastlines from processed_p OSM
        parameters p;
        p["type"]="shape";
        p["file"]="shp/osm/world_boundaries/processed_p";

        Layer lyr("Coastlines");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("landmass");    
        m.addLayer(lyr);
    }

    
    // Swamp  polygons
    if( zoom <= 8 ) {
        parameters p;
        p["type"]="shape";
        p["file"]="shp/swampa";
        
        Layer lyr("Swamp"); 
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("swamp");    
        m.addLayer(lyr);
    }  
    
    // Shelf- and Packice
    {
        parameters p;
        p["type"]="shape";
        p["file"]="shp/seaicea";

        Layer lyr("Seaice");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("seaice");
        lyr.add_style("seaice2");
        m.addLayer(lyr);
    }

    // Grassland  polygons
    if( zoom <= 8 ) {
        parameters p;
        p["type"]="shape";
        p["file"]="shp/grassa";
        
        Layer lyr("Grassland"); 
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("grassland");    
        m.addLayer(lyr);
    }  
    
    // Trees  polygons
    if( zoom <= 8 ) {
        parameters p;
        p["type"]="shape";
        p["file"]="shp/treesa";
        
        Layer lyr("Trees"); 
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("trees");    
        m.addLayer(lyr);
    }  
    
    // Lakes  polygons
    if( zoom >= 8 ) {
        parameters p;
        p["type"]="postgis";
#ifdef DEBUGPOSTGIS
        p["host"]="localhost";
        p["port"]=4444;
#else
        p["host"]="sql-mapnik";
        p["port"]=5432;
#endif
        p["dbname"]="osm_mapnik";
        p["user"]="dschwen";
        p["password"]="";
        p["estimate_extent"]=false;
        p["extent"]="-20037508,-19929239,20037508,19929239";
        p["table"]="(SELECT way, waterway, \"natural\" from planet_polygon where ( waterway in ('riverbank','dock') ) or ( \"natural\" in ('water','bay','wetland','wood', 'grassland','fell') ) ) as foo";

        Layer lyr("Natural"); 
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("lakes2");    
        lyr.add_style("swamp2");    
        lyr.add_style("woods2");    
        lyr.add_style("grass2");    
        m.addLayer(lyr);
    } else 
    {
        parameters p;
        p["type"]="shape";
        p["file"]="shp/inwatera";
        
        Layer lyr("Lakes"); 
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("lakes");    
        m.addLayer(lyr);
    }  

    
    // Landice
    {
        parameters p;
        p["type"]="shape";
        p["file"]="shp/landicea";
        
        Layer lyr("Landice"); 
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("landice");    
        m.addLayer(lyr);
    }

    // Builtup
    if(zoom >= 8 ) {
        parameters p;
        p["type"]="postgis";
#ifdef DEBUGPOSTGIS
        p["host"]="localhost";
        p["port"]=4444;
#else
        p["host"]="sql-mapnik";
        p["port"]=5432;
#endif
        p["dbname"]="osm_mapnik";
        p["user"]="dschwen";
        p["password"]="";
        p["estimate_extent"]=false;
        p["extent"]="-20037508,-19929239,20037508,19929239";
        p["table"]="(SELECT way, landuse,leisure from planet_polygon where landuse in ('military','railway','commercial','industrial','residential','retail','basin','salt_pond','orchard','cemetary','meadow','village_green','forrest','recreation_ground') or leisure in ('dog_park','garden','park','pitch','stadium') ) as foo";

        Layer lyr("Built-up Areas");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("builtup2");   
        lyr.add_style("offlimits");   
        lyr.add_style("greenuse");   
        lyr.add_style("blueuse");   
        m.addLayer(lyr);
        std::cerr << "Added builtup layer\n";
    } else { 
        parameters p;
        p["type"]="shape";
        //p["file"]="shp/builtupa";
        p["file"]="shp/osm/world_boundaries/builtup_area";

        Layer lyr("Built-up Areas");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("builtup");    
        m.addLayer(lyr);
    }

    // Streams
    if(zoom >= 8 ) {
        parameters p;
        p["type"]="postgis";
#ifdef DEBUGPOSTGIS
        p["host"]="localhost";
        p["port"]=4444;
#else
        p["host"]="sql-mapnik";
        p["port"]=5432;
#endif
        p["dbname"]="osm_mapnik";
        p["user"]="dschwen";
        p["password"]="";
        p["estimate_extent"]=false;
        p["extent"]="-20037508,-19929239,20037508,19929239";
        p["table"]="(SELECT way,waterway from planet_line where waterway in ('canal','river','stream')) as foo";

        Layer lyr("Streams");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("canal");    
        lyr.add_style("waterway");    
        if( zoom >= 9 ) lyr.add_style("iwaterway");    
        m.addLayer(lyr);
    }

    // Regional Borders
    {
        parameters p;
        p["type"]="shape";
        p["file"]="shp/polbndl";

        Layer lyr("Regional Borders");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("border2");    
        lyr.add_style("border1");    
        m.addLayer(lyr);
    }
  
    // National Parks
    if(zoom >= 0 ) {
        parameters p;
        p["type"]="shape";
        p["file"]="shp/other/nps_boundary";

        Layer lyr("National Parks");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.add_style("usnps");    
        m.addLayer(lyr);
    }

    // Ferry Lines, Railroadbridges, Causeways
    if(zoom >= 7 ) {
        parameters p;
        p["type"]="postgis";
#ifdef DEBUGPOSTGIS
        p["host"]="localhost";
        p["port"]=4444;
#else
        p["host"]="sql-mapnik";
        p["port"]=5432;
#endif
        p["dbname"]="osm_mapnik";
        p["user"]="dschwen";
        p["password"]="";
        p["estimate_extent"]=false;
        p["extent"]="-20037508,-19929239,20037508,19929239";
        p["table"]="(SELECT way,route from planet_line where route in ('ferry')) as foo";


        Layer lyr("Ferry Lines");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("ferry");   
        // maybe add tram 
        m.addLayer(lyr);
    }
    
    // Railroads
    if(zoom >= 8 ) {
        parameters p;
        p["type"]="postgis";
#ifdef DEBUGPOSTGIS
        p["host"]="localhost";
        p["port"]=4444;
#else
        p["host"]="sql-mapnik";
        p["port"]=5432;
#endif
        p["dbname"]="osm_mapnik";
        p["user"]="dschwen";
        p["password"]="";
        p["estimate_extent"]=false;
        p["extent"]="-20037508,-19929239,20037508,19929239";
        p["table"]="(SELECT way,railway from planet_line where railway in ('rail','preserved')) as foo";

        Layer lyr("Railroads");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("raillines");    
        lyr.add_style("raillines2");    
        m.addLayer(lyr);
    }

    // Unpaved
    if(zoom >= 11 ) {
        parameters p;
        p["type"]="postgis";
#ifdef DEBUGPOSTGIS
        p["host"]="localhost";
        p["port"]=4444;
#else
        p["host"]="sql-mapnik";
        p["port"]=5432;
#endif
        p["dbname"]="osm_mapnik";
        p["user"]="dschwen";
        p["password"]="";
        p["estimate_extent"]=false;
        p["extent"]="-20037508,-19929239,20037508,19929239";
        p["table"]="(SELECT * from planet_line where highway in ('track','path')) as foo";

        Layer lyr("GrayRoads");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("grayroad-border");    
        lyr.add_style("grayroad-fill");    
        m.addLayer(lyr);
    }

    // Residential
    if(zoom >= 10 ) { 
        parameters p;
        p["type"]="postgis";
#ifdef DEBUGPOSTGIS
        p["host"]="localhost";
        p["port"]=4444;
#else
        p["host"]="sql-mapnik";
        p["port"]=5432;
#endif
        p["dbname"]="osm_mapnik";
        p["user"]="dschwen";
        p["password"]="";
        p["estimate_extent"]=false;
        p["extent"]="-20037508,-19929239,20037508,19929239";
        p["table"]="(SELECT way from planet_line where highway in ('residential','tertiary','tertiary_link','unclassified','service')) as foo";

        Layer lyr("WhiteRoads");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("trail-border");    
        lyr.add_style("trail-fill");    
        m.addLayer(lyr);
    }

    // Medium roads
    if(zoom >= 7 ) {
        parameters p;
        p["type"]="postgis";
#ifdef DEBUGPOSTGIS
        p["host"]="localhost";
        p["port"]=4444;
#else
        p["host"]="sql-mapnik";
        p["port"]=5432;
#endif
        p["dbname"]="osm_mapnik";
        p["user"]="dschwen";
        p["password"]="";
        p["estimate_extent"]=false;
        p["extent"]="-20037508,-19929239,20037508,19929239";
        p["table"]="(SELECT way from planet_line where highway in ('primary','primary_link','secondary','secondary_link')) as foo";

        Layer lyr("Highway-border");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("road-border");    
        lyr.add_style("road-fill");    
        m.addLayer(lyr);
    }

    // Highways (roads with median)
    if(zoom >= 6 ) {
        parameters p;
        p["type"]="postgis";
#ifdef DEBUGPOSTGIS
        p["host"]="localhost";
        p["port"]=4444;
#else
        p["host"]="sql-mapnik";
        p["port"]=5432;
#endif
        p["dbname"]="osm_mapnik";
        p["user"]="dschwen";
        p["password"]="";
        p["estimate_extent"]=false;
        p["extent"]="-20037508,-19929239,20037508,19929239";
        p["table"]="(SELECT way from planet_roads where highway in ('motorway','motorway_link','trunk','trunk_link')) as foo";

        Layer lyr("Highway-border");
        lyr.set_datasource(datasource_cache::instance()->create(p));
        lyr.set_srs("+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs");
        lyr.add_style("highway-border");    
        lyr.add_style("highway-fill");    
        m.addLayer(lyr);
        registerLayer(&lyr,7);
    }


    //m.zoomToBox(Envelope<double>(1105120.04127408,-247003.813399447,
    //                             1906357.31328276,-25098.593149577));
    //m.zoomToBox(Envelope<double>(0,0,90,90));
    
    Image32 buf(m.getWidth(),m.getHeight());

    double bx1,by1,bx2,by2;
    int xx;
    std::string base_dir = "tiles/mapnik";
    std::stringstream fname;

    // get the hostname


    if( argc == 2 )
    {
	int z = zoom, x, y;
	FILE *fp, *dfp;
	char readbuf[800];
	char filename[200], tilefile[200];

	// 
	// write the pid to check up on the process later
	//
	sprintf( filename, "/tmp/wikiminiatlas.tile%d.pid", z );
	fp = fopen( filename, "wt" );
	fprintf( fp, "%d", getpid() );
	fclose( fp );

	sprintf( filename, "/tmp/wikiminiatlas.tile%d.fifo", z );

	/* Create the FIFO if it does not exist */
	umask(0);
	mknod( filename, S_IFIFO|0666, 0 );

	std::cout << "Entering fifo command mode for zoom=" << argv[1] << std::endl;
	fp = fopen( filename, "r" );
	while(1)
	{
	  if( fgets( readbuf, 800, fp ) != 0 )
	  {
	    if( sscanf( readbuf, "%d %d", &x, &y ) == 2 )
	    {
	      if( z>=7 )
                sprintf( tilefile, "mapnik/%d/%d/tile_%d_%d.png", z, y, y, x );
              else
		sprintf( tilefile, "mapnik/%d/tile_%d_%d.png", z, y, x );
                        
	      std::cout << "Received location y=" << y << ", x=" << x << ", fname=" << tilefile << std::endl;
				
	      // maybe this request was already in the queue and has been fulfilled
	      dfp = fopen( tilefile,"r");
	      if( dfp ) {
		// exists
		fclose(dfp);
		std::cout << "already created file " << tilefile << std::endl;
                //continue;
	      } 

              // doesnt exist
              if( x >= 3*(1<<z) ) xx = x - 6*(1<<z); 
              else xx = x;

              bx1 = xx*60.0/(1<<z);
              by1 = 90.0 - ( ((y+1.0)*60.0) / (1<<z) );
              bx2 = (xx+1) * 60.0 / (1<<z);
              by2 = 90.0 - ( (y*60.0) / (1<<z) );

              m.zoomToBox(Envelope<double>(bx1,by1,bx2,by2));

              agg_renderer<Image32> ren(m,buf);
              ren.apply(); 

              save_to_file<ImageData32>( buf.data(), tilefile, "png" );
	      
	    } else break;
	    sleep_t = 0;
	  }
	  else
	    if( sleep_t < sleep_max ) sleep_t ++;

	  usleep( sleep_t );
	}
	fclose( fp );

	return EXIT_SUCCESS;
    }
    if( argc == 5 )
    {
        int z = zoom;
        int y = atoi(argv[2]);
        int x = atoi(argv[3]);

	std::cout << "z=" << z << ", y=" << y << ", x=" << x << ", fname=" << argv[4] << std::endl;

	if( x >= 3*(1<<z) ) xx = x - 6*(1<<z); 
	else xx = x;

        bx1 = xx*60.0/(1<<z);
        by1 = 90.0 - ( ((y+1.0)*60.0) / (1<<z) );
        bx2 = (xx+1) * 60.0 / (1<<z);
        by2 = 90.0 - ( (y*60.0) / (1<<z) );

        m.zoomToBox(Envelope<double>(bx1,by1,bx2,by2));

        agg_renderer<Image32> ren(m,buf);
        ren.apply(); 
	
        save_to_file<ImageData32>( buf.data(), argv[4], "png" );

	return EXIT_SUCCESS;
    }
    else
    {
//	return 1;

    	for( int z = 6; z<=6; z++)
    		for( int x = 227; x < 6*(1<<z); x++ )
    			for( int y = 0; y < 3*(1<<z); y++ )
    			{
				fname.str("");
				fname.clear();
				//fname << base_dir << "/" << (z+1) << "/" << y << "/tile_" << y << "_" << x << ".png";
				//fname << z << ".new/" << y << "/tile_" << y << "_" << x << ".png";
				fname << z << ".new/tile_" << y << "_" << x << ".png";
				//sprintf( tilefile, "mapnik/%d/%d/tile_%d_%d.png", z, y, y, x );

				std::cout << fname.str() << std::endl;

				if( x >= 3*(1<<z) ) xx = x - 6*(1<<z); 
				else xx = x;

				bx1 = xx*60.0/(1<<z);
				by1 = 90.0 - ( ((y+1.0)*60.0) / (1<<z) );
				bx2 = (xx+1) * 60.0 / (1<<z);
				by2 = 90.0 - ( (y*60.0) / (1<<z) );

				m.zoomToBox(Envelope<double>(bx1,by1,bx2,by2));

				agg_renderer<Image32> ren(m,buf);
				ren.apply(); 
				save_to_file<ImageData32>( buf.data(), fname.str(), "png" );
			}

    //$file = $dir.'cache/zoom'.$z.'/'.$x.'_'.$y.'_'.$z.'.jpg';
    }

    return EXIT_SUCCESS;
}
