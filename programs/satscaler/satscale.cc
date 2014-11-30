/************************************************************************
 *
 * Satellite data tile rescaler (c) 2009-2010 by Daniel Schwen
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.
 *
 ************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>

#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#ifdef LINUX
#include <linux/stat.h>
#endif

extern "C" {
#include "http_fetcher.h"
}

#include "IL/il.h"
#include "IL/ilu.h"

/* Nasa tile scheme
 *
 *     90
 * -180 A--*-----------------
 *      |  |
 *      *--B
 *      |            bb=Alon,Blat,Blon,Alat
 *      |
 *
 *      |
 * -180 *-----------------
 *    -90
 */

// Nasa parameter
const int tilesize = 512;
const int nasa_levels = 13;
const double degsize[nasa_levels] = { 256.0, 128.0, 64.0, 32.0, 16.0, 8.0, 4.0, 2.0, 1.0, 0.5, 0.25, 0.125, 0.0625 };

// WMA parameter
const int max_zoomlevel = 13; // 0....5 (6 level)
const int zoomlevel[max_zoomlevel+1] = {  3, 6, 12, 24, 48, 96, 192, 384, 768, 1536, 3072,  6144, 12288, 24576 }; // degsize = 180/zoomlevel

const char *reqtemp = "GetMap&layers=global_mosaic&srs=EPSG:4326&width=%d&height=%d&bbox=%f,%f,%f,%f&format=image/jpeg&version=1.1.1&styles=default";
//const char *reqtemp = "GetMap&layers=global_mosaic&srs=EPSG:4326&width=%d&height=%d&bbox=%f,%f,%f,%f&format=image/jpeg&version=1.1.1&styles=";
const char *baseurl = "http://onearth.jpl.nasa.gov/wms.cgi?request=%s";

// WMA tiles
//const char *path  = "/projects/wma/www/tiles/mapnik/sat/%d/%d/%d_%d.png"; // z,y,y,x
//const char *path2 = "/projects/wma/www/tiles/mapnik/sat/%d/%d"; // z,y
const char *path  = "mapnik/sat/%d/%d/%d_%d.png"; // z,y,y,x
const char *path2 = "mapnik/sat/%d/%d"; // z,y

// original nasa tiles
const char *patho = "mapnik/sat/originals/%d/%d/%d.jpg"; // z,y,x
const char *patho2 = "mapnik/sat/originals/%d/%d"; // z,y

// assemble the tile path into fname
void tilename( int x, int y, int z, char *fname )
{
  sprintf( fname, path, z, y, y, x );
}

// assemble the tile directory into fname
void tilepath( int x, int y, int z, char *fname )
{
  sprintf( fname, path2, z, y );
}

// check whether a file already exists
bool file_exists( char *fname )
{
  if( FILE * file = fopen( fname, "r" ) )
  {
    fclose( file );
    return true;
  }
  return false;
}

// yikes, globals!
ILuint im_load;
ILuint im_work;
ILuint im_tile;

struct stat sb;

int tilerequest( int x, int y, int z )
{
  ilInit();
  iluInit();

  const int nx = (tilesize/128);
  const int ny = nx;

  char fname[1000], request[1000], dir[1000], url[1000];
  char *buf;
  int len;

  tilename( x, y, z, fname );
  if( file_exists( fname ) ) return 0;

  // get degree window for the tile x,y,z
  double wmatiledeg;
  double bx1, by1, bx2, by2;
  wmatiledeg = 60.0/(1<<z);

  if( x >= 3*(1<<z) ) x -= 6*(1<<z);
  
  // bx1,by1 is top-left-corner
  bx1 = x * wmatiledeg;
  by1 = 90.0 - ( y + 0.0 ) * wmatiledeg;
  //bx2 = ( x + 1.0 ) * wmatiledeg;
  //by2 = 90.0 - y * wmatiledeg;

  // compare degrees per pixel
  double wmadpp = wmatiledeg / 128;

  // find the nasa zoomlevel that barely has less degrees per pixel, than the requested tile
  int nasa_z;
  for( nasa_z = 0; nasa_z < nasa_levels - 1; nasa_z++ )
    if( degsize[nasa_z]/tilesize <= wmadpp ) break;
  if( nasa_z == nasa_levels ) return 1;

  // find the nasa tile, that comtains the top-left corner of the WMA tile
  int ntx = int( ( bx1 + 180.0 ) / degsize[nasa_z] );
  int nty = int( ( 90.0 - by1 ) / degsize[nasa_z] );

  printf(" lat/by1=%f lon/bx1=%f\n", by1, bx1 );
  printf(" nasa_z=%d, ntx=%d, nty=%d\n", nasa_z, ntx, nty );


  float Alat, Alon, Blat, Blon;
    FILE *ocache;

  // get the four nasa tiles
  for( int tx = 1; tx >=0; tx--)
    for( int ty = 1; ty >=0; ty--)
    {
      Alat = 90.0 - (nty+ty)*degsize[nasa_z];
      Blat = Alat - degsize[nasa_z];
      Alon = -180.0 + (ntx+tx)*degsize[nasa_z];
      Blon = Alon + degsize[nasa_z];

      ilBindImage( im_load );

      // did we cache that original tile to disk already?
      sprintf( fname, patho, nasa_z, nty+ty, ntx+tx );
      if( file_exists( fname ) )
      {
        printf( " using ocache\n" );
        if( !ilLoad( IL_JPG, fname ) )
        {
            // was the cache file empty? then generate a black tile
            ilTexImage( tilesize, tilesize, 0, 3, IL_RGB, IL_UNSIGNED_BYTE, 0 );
            ilClearImage();
        }
      }
      else
      {
        sprintf( request, reqtemp, tilesize, tilesize, Alon, Blat, Blon, Alat );
        sprintf( url, baseurl, request );
        len = http_fetch( url, &buf );
        printf(" downloaded: %d bytes\nfrom: %s\n", len, url );

        if( !ilLoadL( IL_JPG, buf, len ) )
        {
          // produce a black tile if no valid satellite data was returned
          printf( buf );
          ilTexImage( tilesize, tilesize, 0, 3, IL_RGB, IL_UNSIGNED_BYTE, 0 );
          ilClearImage();

          // set length to zero, to write an empty cache file (avoids subsequent requests)
          len = 0;
        }

        // writing downloaded tile to disk (even if it's empty!)
        sprintf( dir, patho2, nasa_z, nty+ty );
        if( stat( dir, &sb ) == -1) 
        {
          printf( " ocache directory %s does not yet exist, creating..\n", dir );
          if( errno == ENOENT )
            if( mkdir( dir, 0777 ) == -1 ) printf(" error!\n" );
        }

        ocache = fopen( fname, "w" );
        if( ocache != NULL )
        {
          fwrite( buf, len, 1, ocache );
          fclose( ocache );
        }
        else
          printf(" error writing ocache %s \n", fname );
      }

      ilBindImage( im_work );
      ilOverlayImage( im_load, tx*tilesize, ty*tilesize, 0 );
      
      free( buf );
      buf = 0;
    }    

  // Alat, Alon should now contain the top left corner of the work area
      
  // now find the wma tile again, that fully fits in the top-left corner of the top left nasa tile
  int wtx = int( ( double(ntx) * degsize[nasa_z] - 180.0 ) / wmatiledeg );
  //if( wtx < 0.0 ) wtx += 360.0; 
  //wtx /= wmatiledeg;
  int wty = int( ( double(nty) * degsize[nasa_z] ) / wmatiledeg );

  //wtx = int( Alon/180.0 * zoomlevel[z] );
  //wty = int( ( 90 - Alat ) / 180.0 );


  printf( " wtx, wty = %d %d, Alon, Alat = %f,%f    %f %f \n",  wtx, wty,Alon, Alat, ( wtx * wmatiledeg - Alon )  * tilesize / degsize[nasa_z],  wty * wmatiledeg - Alat   );

  int Apx, Apy, Bpx, Bpy, tw, th, xx;
  ilBindImage( im_tile );
  //for( int ty = wty+1; ty > wty - (2.0*degsize[nasa_z]/wmatiledeg) - 1; ty-- )
  for( int tx = wtx-2; tx < wtx + (2.0*degsize[nasa_z]/wmatiledeg) + 2; tx++ )
    for( int ty = wty-2; ty < wty + (2.0*degsize[nasa_z]/wmatiledeg) + 2; ty++ )
    {
      Apx = int( ( ( tx     * wmatiledeg - Alon ) * tilesize ) / degsize[nasa_z] );
      Bpx = int( ( ( (tx+1) * wmatiledeg - Alon ) * tilesize ) / degsize[nasa_z] );

      Apy = -int( ( ( 90 - ty     * wmatiledeg - Alat ) * tilesize ) / degsize[nasa_z] );
      Bpy = -int( ( ( 90 - (ty+1) * wmatiledeg - Alat ) * tilesize ) / degsize[nasa_z] );


      //printf(" (%d,%d) cutting (%d,%d)-(%d,%d)\n", tx, ty, Apx, Apy, Bpx, Bpy );
      if( Apx >= 0 && Apy >= 0 && Bpx <= 2*tilesize && Bpy <= 2*tilesize )
      {
        if( tx <0 ) xx = tx + 6*(1<<z);
        else xx = tx;
        
        // does the tile path exist? if not, make it!
        tilepath( xx, ty, z, dir );
        if( stat( dir, &sb ) == -1) 
        {
          printf( " directory %s does not yet exist, creating..\n", dir );
          if( errno == ENOENT )
            if( mkdir( dir, 0777 ) == -1 ) printf(" error!\n" );
        }

        tilename( xx, ty, z, fname );
        if( !file_exists( fname ) )
        {
          tw = Bpx - Apx;
          th = Bpy - Apy;
        
          //printf( "new image %d x %d\n", tw, th ); 
          ilTexImage( tw, th, 0, 3, IL_RGB, IL_UNSIGNED_BYTE, 0 );
        

          // crop it from the work image
          ilBlit( im_work, 0, 0, 0, Apx, Apy, 0, tw, th, 1 );

          // scale it to 128x128
          iluImageParameter( ILU_FILTER, ILU_LINEAR );
          iluScale( 128, 128, 1 );

          // sharpen the sat data a little bit
          //iluSharpen( 1.75, 1 );

          ilSave( IL_PNG, fname );
          printf( "%s (%x)\n", fname, ilGetError() );
        }
        else printf(" already rendered %s\n", fname );
      }
    }


  /*
  FILE *out = fopen( "debug.jpg", "w" );
  fwrite( buf, len, 1, out );
  fclose( out );
  */

  return 0;
}


int main( int argc, char *argv[] )
{
  FILE *fp;

  //
  // write the pid to check up on the process later
  //
  fprintf( stderr, "writing pid file.\n" );
  fp = fopen( "/tmp/wikiminiatlas.sat.pid", "wt" );
  fprintf( fp, "%d", getpid() );
  fclose( fp );

  fprintf( stderr, "initializing DevIL.\n" );
  ilInit();
  iluInit();
  ilClearColour( 0, 0 , 0 , 0 );

  im_load = ilGenImage();
  im_work = ilGenImage();
  im_tile = ilGenImage();
  
  ilBindImage( im_work );
  ilTexImage( 2*tilesize, 2*tilesize, 0, 3, IL_RGB, IL_UNSIGNED_BYTE, 0 );

  int x, y, z;
  char readbuf[800];

  const int sleep_max = 100000;
  int sleep_t = 1000;

  // Create the FIFO if it does not exist
  umask(0);
  mknod( "/tmp/wikiminiatlas.sat.fifo", S_IFIFO|0666, 0 );

  fprintf( stderr, "opening fifo.\n" );
  fp = fopen( "/tmp/wikiminiatlas.sat.fifo", "r" );
  if( fp == 0 )
  {
    fprintf( stderr, "Unable to open fifo\n" );
    return 1;
  }

  fprintf( stderr, "entering main loop..\n" );
  while(1)
  {
    if( feof(fp) ) rewind(fp);

    if( fgets( readbuf, 800, fp ) != 0 )
    {
      if( sscanf( readbuf, "%d %d %d", &x, &y, &z ) == 3 ) 
      {
        //fprintf( stderr, "entering tilerequest %d %d %d.\n", x, y, z );
        tilerequest( x, y, z );
        //fprintf( stderr, "left tilerequest.\n" );
      }
      else
      {
        fprintf( stderr, "read: %s\n", readbuf );
        break;
      }
      sleep_t = 1000;
      continue;
    }
    else
      if( sleep_t < sleep_max ) sleep_t *= 2;

    usleep( sleep_t );
    //fprintf( stderr, "looping... %d\n", feof(fp) );
  }
}

