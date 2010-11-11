
#Solaris
#g++ satscale.cc -o satscale -Iinclude lib/libIL.a lib/libILU.a lib/libhttp_fetcher.a -ljpeg -lpng -ltiff -lz -lresolv -lsocket -lnsl
g++ satscale.cc -o satscale -Iinclude lib/libIL.a lib/libILU.a lib/libhttp_fetcher.a -L/opt/ts/lib -ljpeg -lpng -ltiff -lz -lresolv -lsocket -lnsl -R/opt/ts/lib

# Linux
#g++ satscale.cc -o satscale -Iinclude lib/libIL.a lib/libILU.a lib/libhttp_fetcher.a -ljpeg -lpng -lmng -ltiff -llcms -lz

