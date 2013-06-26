#!/bin/bash
g++  mapniktile4.cc -o mapniktile4 `mapnik-config --cflags --libs --ldflags --dep-libs`
