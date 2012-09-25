#!/bin/bash
g++ -g -pthread -O3 `freetype-config --cflags` -lstdc++ `mapnik-config --libs` -licuuc  mapniktile4.cc -o mapniktile4
