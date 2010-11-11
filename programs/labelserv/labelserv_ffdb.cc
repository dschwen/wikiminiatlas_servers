/************************************************************************
 *
 * Lable server for WikiMiniAtlas (c) 2009-2010 by Daniel Schwen
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

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <signal.h>
#include <pthread.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define BUFSIZE 8096
#define ERROR 42
#define SORRY 43
#define LOG   44 

const int max_zoomlevel = 13; // 0....5 (6 level)
const int zoomlevel[max_zoomlevel+1] = {  3, 6, 12, 24, 48, 96, 192, 384, 768, 1536, 3072,  6144, 12288, 24576 }; 

const int max_styles = 10;
int icon_off_x[max_styles+1];
int icon_off_y[max_styles+1];

//globals for profiling
int nodes_created;
int snodes_created;
int places_created;

int nlang = 0;
const int nlang_max = 22;
//		                      0     1     2     3     4     5     6     7     8     9    10    11    12    13    14    15    16    17   18,   19
//char languages[][nlang] = { "de", "en", "ja", "pl", "pt", "nl", "it", "fr", "is", "ca", "no", "es", "ru", "eo", "hu", "sv", "lt", "eu", "ko", "el"};
char *languages[nlang_max];

// Flat file database handle
FILE *ffdb;


//
// Temporary fat tree components - used for sorting and building the flatfile database
//

struct place
{
  float lat, lon;
  int pop, psize;
  unsigned char style;
  char *name; 

  bool operator<(const place &a) const { return (this->psize+this->pop/20) < (a.psize+a.pop/20); }
  bool operator>(const place &a) const { return (this->psize+this->pop/20) > (a.psize+a.pop/20); }
  place() { name = 0; }
  ~place() { delete[] name; }
};

struct node
{
  place* places[4];
  node *sub[4];

  node() 
  { 
    for( int i = 0; i < 4; ++i ) 
      { sub[i] = 0; places[i] = 0; } 
  };
  ~node()
  {
    bool bottom = true;
    for( int i = 0; i < 4; ++i )
      if( sub[i] != 0 ) bottom = false;
    if( bottom ) 
      for( int i = 0; i < 4; ++i )
        if( places[i] != 0 ) delete places[i];
  }
} *base[3][6];


//
// Slim tree node - indexes the flatfile database
//
struct snode // new slim tree node
{
  int index[nlang_max]; // position of titles (-1 for not existant)
  snode *sub[4];

  snode() 
  { 
    sub[0]=0; sub[1]=0; sub[2]=0; sub[3]=0; 
    for( int i = 0; i < nlang; i++ ) index[i] = -1;
  };
} *sbase[3][6];


// 
// Insert a place into the highest zoomlevel of the temporary fat tree
//
bool insertPlace(place *p,int by, int bx)
{
    int ly = int( ( 90.0 + p->lat ) / 180.0 * zoomlevel[max_zoomlevel] );  // tileindex im hoechsten zoomlevel
    int lx = int( p->lon / 360.0 * zoomlevel[max_zoomlevel] * 2 );
    int quad;

    node *n = base[by][bx];

    for(int i = 0; i < max_zoomlevel; ++i)
    {
   	quad = ( ( lx >> ( max_zoomlevel - i - 1 ) ) & 1) + 2 * ( ( ly >> ( max_zoomlevel - i - 1 ) ) & 1);
        if(n->sub[quad] == 0) 
        { 
          n->sub[quad] = new node; 
          nodes_created++; 
        }
        n = n->sub[quad];
    }

    for(int i = 0; i < 4; ++i )
      if( n->places[i] == 0 || *(n->places[i]) < *p )
      {
        n->places[i] = p;
        break;
      }

    places_created++;
    return true;
}

// 
// get the the slim tree node for a given tile coordinate
//
snode* getNode(int ty, int tx, int z)
{
    // z=0 -> base zoom 
    int bx = tx / (1 << z);  
    int by = ty / (1 << z);
    if( bx >= 6 || bx < 0 || by < 0 || by >= 3 ) return 0;
    int quad;

    snode* n = sbase[by][bx];  
    for(int i=0; i<z; ++i)
    {
   	quad = ((tx >> (z-i-1)) & 1) + 2*((ty >> (z-i-1)) & 1);
        if(n->sub[quad] != 0) n = n->sub[quad];
        else return 0;
    }
    return n;
}

//
// populate the temporary fat tree
//
void recursePopulate(node *n)
{
  for(int i=0; i<4; ++i) if (n->sub[i]!=0) recursePopulate(n->sub[i]);

  int k = 0;
  for(int i=0; i<4; ++i) if (n->sub[i]!=0)
  {
    // node exists, so it cannot be empty
    n->places[k] = n->sub[i]->places[0];

    for(int j = 1; j < 4 && n->sub[i]->places[j] != 0 ; ++j )
    {
      if( n->places[k] == 0 || *(n->sub[i]->places[j]) > *(n->places[k]) )
        n->places[k] = n->sub[i]->places[j];
    }

    if( n->places[k] != 0 ) k++;
    places_created++;
  }   

//  sort(n->places.begin(), n->places.end());
}

// 
// dump the temporary fat tree into the flatfile database
// create slim index tree
// free temporary fat tree
// (uses global ffdb handle)
//
inline int min(int a, int b) { return a < b ? a : b; }
void dumpNode( node *src, snode *dst, int lang )
{
  unsigned char n1, n2,u;
  // dump data in this node
  dst->index[lang] = ftell(ffdb);

  for( n1 = 0; src->places[n1] != 0 && n1 < 4; ++n1 );
  fwrite( &n1, 1, 1, ffdb );

  for( u = 0; u < n1; u++ )
  {
    fwrite( &(src->places[u]->lat), sizeof(float), 1, ffdb );
    fwrite( &(src->places[u]->lon), sizeof(float), 1, ffdb );
    fwrite( &(src->places[u]->style), 1, 1, ffdb );
    n2 = (unsigned char)( min( 250, strlen( src->places[u]->name ) ) );
    fwrite( &n2, 1, 1, ffdb );
    fwrite( src->places[u]->name, n2, 1, ffdb );
  }

  // process subnodes
  for( int j = 0; j < 4; j++)
  {
    if( src->sub[j] != 0 )
    {
      if( dst->sub[j] == 0 ) 
      {
        dst->sub[j] = new snode;
        snodes_created++;
      }
      dumpNode( src->sub[j], dst->sub[j], lang );
    }
  }

  // done with this node, delete it
  delete src;
}

const char hexes[]="0123456789ABCDEF";
void uriencode( const char *src, char *dest )
{
  int i = 0, j = 0;
  while( j < 299 && src[i] != 0 )
  {
    if( ( src[i] >= 'a' && src[i] <= 'z' ) ||
        ( src[i] >= 'A' && src[i] <= 'Z' ) ||
        ( src[i] >= '0' && src[i] <= '9' ) ||
	( src[i] == '-' )             ||
	( src[i] == '_' )             ||
	( src[i] == '.' )             ||
	( src[i] == '*' ) ) dest[j++] = src[i++]; // just copy
    else if( src[i] == ' ' && i>0 ) { dest[j++] = '_'; i++; }
    else if( src[i] == ' ' && i==0 ) i++;
    else
    {
      dest[j++] = '%';
      dest[j++] = hexes[ ( src[i] >> 4 ) & 0xF ];
      dest[j++] = hexes[ src[i++] & 0xF ];
    }
  }
  dest[j] = 0;
}

// 
// this is a child web server process, so we can exit on errors
//
void *web(void *data)
{
  int j, k, file_fd, buflen, len, fd = (int)data;
  int x,y,z, tx,ty;
  long i, ret;
  snode *n;
  char encbuf[300];
  char buffer[ BUFSIZE + 1 ];
  unsigned char n1, n2, u;
    
  // read client request
  ret = recv( fd, buffer, BUFSIZE, 0 );

  // zero terminate request
  if( ret > BUFSIZE ) ret = BUFSIZE;  
  if(ret < 0 ) ret = 0;
  buffer[ret]=0; 

  // remove CF and LF characters
  for( i = 0; i < ret; i++ )
     if(buffer[i] == '\r' || buffer[i] == '\n') buffer[i]='*';
    
  if( strncmp( buffer, "GET ", 4 ) && 
      strncmp( buffer, "get ", 4 ) )
  {
    printf( "only GET is supprted: %s\n", buffer );
    ret = 0;
  }
    
  // null terminate after the second space to ignore extra stuff
  for( i = 4; i < ret; i++ ) 
  {
    if(buffer[i] == ' ') 
    {
      buffer[i] = 0;
      break;
    }
  }
    
  // last param is the lang code (see .htaccess !)
  int lang;
  if( sscanf( buffer, "GET /%d_%d_%d_%d\0", &y, &x, &z, &lang ) !=4 &&
      sscanf( buffer, "GET /~dschwen/wma/proxy/%d_%d_%d_%d\0", &y, &x, &z, &lang ) !=4 ) 
  {
    sprintf(buffer, "HTTP/1.0 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n<HTML><BODY><H1>Tile Server Sorry: failed to parse coordinate </H1></BODY></HTML>\r\n" );
    send( fd, buffer, strlen( buffer ), 0 );
#ifdef LINUX
    sleep(1);       /* to allow socket to drain */
#endif
    close(fd);
    return 0;
  }
    
printf(" looking up %d %d %d in %d\n", y, x, z, lang );

  sprintf(buffer, "HTTP/1.0 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n");
  send( fd, buffer, strlen(buffer), 0 );
    
  //create a decent array index
  int istyle;

  //Koordinate scannen und in einen textpuffer schreiben!
  n = getNode( y, x, z );
  len = 0;
  buffer[0] = 0;

  if( n == 0 || lang < 0 || lang >= nlang )
  {
    sprintf(&buffer[0],"\n\0");
  }
  else
  {
    FILE *rffdb = fopen( "wp_coord.ffdb.2", "r" );
    unsigned char n1, n2;
    char name[256];
    //char *realname = name;
    char *realname;

    float lat, lon;
    fseek( rffdb, n->index[lang], SEEK_SET );
    fread( &n1, 1, 1, rffdb ); // number of labels in this tile

    for( j = 0; j < int(n1); ++j)
    {
      fread( &lat, sizeof(float), 1, rffdb );
      fread( &lon, sizeof(float), 1, rffdb );

      ty = int( ( ( 90.0 - lat) * zoomlevel[z] * 128 ) / 180.0 ) - ( zoomlevel[z] - y - 1 ) * 128; 
      tx = int( ( lon * zoomlevel[z] * 256 ) / 360.0 ) - 128 * x;

      fread( &n2, 1, 1, rffdb );
      istyle = int(n2);

      fread( &n2, 1, 1, rffdb );
      fread( name, n2, 1, rffdb );
      realname = name;
      name[int(n2)] = 0;
      bool ital = false;
      for( k = 0; k < int(n2); k++ )
        if( name[k] == '|' )
        {
          realname = &name[k+1];
          name[k] = 0;
          ital = true;
          break;
        }
      
      uriencode( realname, encbuf );
      if( ital ) 
      {
        len += 
          snprintf( &buffer[len],
                    BUFSIZE - len - 2, 
                    "<a href=\"http://%s.wikipedia.org/wiki/%s\" target=\"_top\" class=\"label%d\" style=\"top:%dpx; left:%dpx;\"> <i>%s</i></a>\n\0",
                    languages[lang], encbuf, istyle, ty-icon_off_y[istyle], tx-icon_off_x[istyle], name )-1;
      }
      else
      {
        len += 
          snprintf( &buffer[len],
                    BUFSIZE - len - 2, 
                    "<a href=\"http://%s.wikipedia.org/wiki/%s\" target=\"_top\" class=\"label%d\" style=\"top:%dpx; left:%dpx;\"> %s</a>\n\0",
                    languages[lang], encbuf, istyle, ty-icon_off_y[istyle], tx-icon_off_x[istyle], name )-1;
      }
    }

    fclose( rffdb );
    send( fd, buffer, len+1, 0);
  }
    
#ifdef LINUX
  sleep(1);       /* to allow socket to drain */
#endif
  close(fd);
  return 0;
}

main(int argc, char **argv)
{
  int i, port, pid, listenfd, socketfd, hit;
  char *str;
  char buf[1000];

  int by,bx;

  if( argc < 2  || argc > 2 || !strcmp(argv[1], "-?") ) 
  {
    (void)printf("hint: tileserv Port-Number\n\n"
                 "\ttileserv is a small and very safe mini coordinate web server\nfor the WikiMiniAtlas.\n"
                 "\tExample: tileserv 8181 &\n\n");
    exit(0);
  }

  // ignore SIGPIPE
  signal(SIGPIPE, SIG_IGN);

  // set label icon offsets
  icon_off_x[0]=0; icon_off_y[0]=0; // standard
  icon_off_x[1]=0; icon_off_y[1]=0; // standard
  icon_off_x[2]=5; icon_off_y[2]=8; // standard
  icon_off_x[3]=0; icon_off_y[3]=0; // standard
  icon_off_x[4]=0; icon_off_y[4]=0; // standard
  icon_off_x[5]=2; icon_off_y[5]=2; // standard
  icon_off_x[6]=3; icon_off_y[6]=3; // standard
  icon_off_x[7]=4; icon_off_y[7]=4; // standard
  icon_off_x[8]=5; icon_off_y[8]=5; // standard
  icon_off_x[9]=6; icon_off_y[9]=6; // standard
  icon_off_x[10]=6; icon_off_y[10]=6; // event    
  ffdb = fopen( "wp_coord.ffdb.2", "w" );

  // Read table of supported languages
  const char *lfname = "/home/dschwen/wma_rewrite.txt";
  FILE *langfile = fopen( lfname, "rt" );
  if( langfile == NULL )
  {
    fprintf( stderr, "Could not open language table at '%s'\n", lfname );
    return 1;
  }
  nlang = 0;
  int id;
  while( !feof( langfile ) )
  {
    if( fscanf( langfile, "%s %d", buf, &id ) == 2 && id == nlang )
    {
      if( nlang == nlang_max )
      {
        fprintf( stderr, "Language table too large. Please increase nlang_max and recompile labelserv_ffdb.\n" );
        return 1;
      }
      languages[nlang] = (char*)calloc( strlen(buf) + 1, 1 );
      strcpy( languages[nlang], buf );
      fprintf( stderr, "%s %d\n", buf, id );
      nlang++;
    }
    else
    {
      fprintf( stderr, "Language table - ignoring: '%s %d' (nlang=%d)\nElements have to be in order.\n", buf, id, nlang );
    }
  }
    

  // Read coordinates

  for(int x=0; x<6; ++x)
    for(int y=0; y<3; ++y)
      sbase[y][x] = new snode;

  int n=0;
  place* newplace;
  snodes_created = 0;

  char dataname[200];
  char line[5000];
  FILE *datafile;
  for( i = 0; i < nlang; i++ )
  {
    // Read one language and populate temporary tree
    printf( "lang=%s\n", languages[i] );

    for(int x=0; x<6; ++x)
      for(int y=0; y<3; ++y)
        base[y][x] = new node;

    places_created = 0;
    nodes_created = 0;
    n = 0;

    sprintf( dataname, "wp_coord_%s.txt", languages[i] );
    //ifstream iFile( dataname );
    //while(iFile.good())
    datafile = fopen( dataname, "rt" );
    if( !datafile )
    {
      printf( "Could not open datafile %s\n", dataname );
      return 1;
    }

    while( !feof( datafile ) )
    {
      newplace = new place;
      fgets( line, 5000, datafile );

      if( sscanf( line, "%f %f %d %d %u %[^\r\n]\r\n", &newplace->lon, &newplace->lat, &newplace->pop, &newplace->psize, &newplace->style, buf )
         != 6 ) 
      { 
        printf( "read error line:\n%s", line ); 
        return 1; 
      }

      if( newplace->lon < 0 ) newplace->lon += 360.0;

      by = int( ( ( 90.0 + newplace->lat ) * 3 ) / 180.0 );
      bx = int( ( newplace->lon * 6 ) / 360.0 );

      //printf("read %f %f %d %d %d\n%s\n", newplace->lon, newplace->lat, newplace->pop, newplace->psize, newplace->style, buf );

      if( bx<6 && by<3 && bx>=0 && by>=0) 
      {
        if( insertPlace( newplace, by, bx ) )
        {
          newplace->name = new char[ strlen(buf) + 1 ];
          strcpy( newplace->name, buf );
        }
        else delete newplace;
      }
      n++;
    }
    printf( "%d nodes created. %d places created. %d lines of input.\n", nodes_created, places_created, n );

    for(int x=0; x<6; ++x)
      for(int y=0; y<3; ++y)
         recursePopulate(base[y][x]);

    printf( "%d total places created.\n", places_created );

    // Dump temporary tree data to disk
    // Insert nodes in new slim tree
    // delete temporary tree node

    for(int x=0; x<6; ++x)
      for(int y=0; y<3; ++y)
        dumpNode( base[y][x], sbase[y][x], i );

    printf( "%d total slim-nodes created so far.\n", snodes_created );
  }

  fclose( ffdb );

  // Initialize internal Webserver
   
  // static = initialised to zeros
  static struct sockaddr_in cli_addr; 
  static struct sockaddr_in serv_addr; 
       
/*
  // Become deamon + unstopable and no zombies children (= no wait()) 
  // parent returns OK to shell
  if( fork() != 0 ) return 0; 
    
  // ignore child death
  (void)signal(SIGCLD, SIG_IGN); 
  // ignore terminal hangups
  (void)signal(SIGHUP, SIG_IGN); 
    
  // close open files
  for( i = 0; i < 32; i++ ) (void)close(i);
    
  // break away from process group
  (void)setpgrp();             
*/  
  printf( "tileserv starting..." );
    
  // setup the network socket
  if((listenfd = socket(AF_INET, SOCK_STREAM,0)) <0)
  {
    printf( "system call: socket\n" );
    return 1;
  }
    
  port = atoi(argv[1]);
  if(port < 0 || port >60000)
  {
    printf( "Invalid port number (try 1->60000)\n" );
    return 1;
  }

  /* Enable address reuse */
  int on = 1;
  int ret = setsockopt( listenfd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on) );
  if( ret != 0 ) 
  {
    printf( "system call: setsockopt\n" );
    return 1;
  }
    
  serv_addr.sin_family = AF_INET;
  serv_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  serv_addr.sin_port = htons(port);
    
  if(bind(listenfd, (struct sockaddr *)&serv_addr,sizeof(serv_addr)) <0)
  {
    printf( "system call: bind\n" );
    return 1;
  }

  // 64 socket queue slots
  if( listen( listenfd, 64 ) < 0 )
  {
    printf( "system call: listen\n" );
    return 1;
  }

  while(1)
  {
    int client;
    socklen_t length = sizeof(cli_addr);
    pthread_t child;

    client = accept( listenfd, (struct sockaddr*)&cli_addr, &length );

    if ( pthread_create(&child, NULL, web, (void*)client) != 0 )
      perror("Thread creation");
    else
      pthread_detach(child);  /* disassociate from parent */
  }

}
