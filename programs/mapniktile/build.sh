#!/bin/bash

# hemlock (debian linux)
#g++ -O3 -I/opt/ts/include/mapnik -I/usr/include/freetype2 -lmapnik mapniktile.cc -o mapniktile

# willow (sun solaris)
#g++  -R/opt/ts/lib -O3 -I/usr/sfw/include/freetype2 -I/opt/ts/include -I/opt/boost/include/boost-1_35 -L/usr/sfw/lib -L/opt/ts/lib -L/opt/boost/lib -lmapnik mapniktile.cc -o mapniktile

# new stable
#sunCC -mt -library=stlport4 -licuuc -R/opt/ts/lib -O3 `freetype-config --cflags` -I/opt/ts/include -I/opt/boost/include/boost-1_35 -L/usr/sfw/lib -L/opt/ts/lib -L/opt/boost/lib -lmapnik mapniktile.cc -o mapniktile
#sunCC -mt -library=stlport4 -licuuc -R/opt/ts/lib -O3 `freetype-config --cflags` -I/opt/ts/include -I/opt/ts/boost/1.39/include -L/usr/sfw/lib -L/opt/ts/lib -L/opt/ts/boost/1.39/lib -lmapnik mapniktile.cc -o mapniktile

sunCC -mt -library=stlport4 -R/opt/ts/lib -O3 `freetype-config --cflags` -I/opt/ts/include -I/opt/ts/boost/1.39/include -L/usr/sfw/lib -L/opt/ts/lib -L/opt/ts/boost/1.39/lib -lmapnik -licuuc  mapniktile.cc -o mapniktile

