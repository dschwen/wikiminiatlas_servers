mapniktile4: mapniktile4.cc
	g++  mapniktile4.cc -o mapniktile4 `mapnik-config --cflags --libs --ldflags --dep-libs` `pkg-config --cflags sigc++-2.0` -DMAPNIK_PLUGINS=\"`mapnik-config --input-plugins`\"

install: mapniktile4
	sudo cp -a mapniktile4 /usr/local/bin
