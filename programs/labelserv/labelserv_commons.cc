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

#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <algorithm>

#include "math.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>


#define BUFSIZE 8096
#define ERROR 42
#define SORRY 43
#define LOG   44



using namespace std;

const int max_zoomlevel = 13; // 0....5 (6 level)
const int zoomlevel[max_zoomlevel+1] = {  3, 6, 12, 24, 48, 96, 192, 384, 768, 1536, 3072,  6144, 12288, 24576 }; 

const int max_styles = 9;
int icon_off_x[max_styles+1];
int icon_off_y[max_styles+1];

//globals for profiling
int nodes_created = 0;
int places_created = 0;

struct place
{
    float lat, lon;
    int imgw, imgh, psize;
    unsigned char twidth, dir;
    string name;

    bool operator<(const place &a) const { return (this->psize) > (a.psize); } //inverse sorting!

    place(float lat_, float lon_,
          int psize_, unsigned char twidth_, int imgw_, int imgh_,
          const string &name_, unsigned char dir_ ) 
        : lat(lat_), lon(lon_), psize(psize_), twidth(twidth_), imgw(imgw_), imgh(imgh_), name(name_), dir(dir_) {};
};

struct node
{
    vector<place> places;
    node *sub[4];

    node() { sub[0]=0; sub[1]=0; sub[2]=0; sub[3]=0; };
} *base[3][6];


// Insert a place into the highest zoomlevel
void insertPlace(place p,int by, int bx)
{
    int ly = int((90.0+p.lat)/180.0* zoomlevel[max_zoomlevel]);  // tileindex im hoechsten zoomlevel
    int lx = int(p.lon/360.0* zoomlevel[max_zoomlevel]*2);
    int quad;

    node *n=base[by][bx];

    for(int i=0; i<max_zoomlevel; ++i)
    {
   	quad = ((lx >> (max_zoomlevel-i-1)) & 1) + 2*((ly >> (max_zoomlevel-i-1)) & 1);
        if(n->sub[quad] == 0) { n->sub[quad] = new node; nodes_created++; }
        n = n->sub[quad];
    }
    n->places.push_back(p);
    places_created++;
}

node* getNode(int ty, int tx, int z)
{
    // z=0 -> base zoom 
    int bx = tx / (1 << z);  
    int by = ty / (1 << z);
    if( bx>=6 || bx<0 || by<0 || by>=3 ) return 0;
    int quad;

    node* n=base[by][bx];  
    for(int i=0; i<z; ++i)
    {
   	quad = ((tx >> (z-i-1)) & 1) + 2*((ty >> (z-i-1)) & 1);
        if(n->sub[quad] != 0) n = n->sub[quad];
        else return 0;
    }
    return n;
}

void recursePopulate(node *n)
{
    for(int i=0; i<4; ++i) if (n->sub[i]!=0) recursePopulate(n->sub[i]);

    for(int i=0; i<4; ++i) if (n->sub[i]!=0)
    {
    	// node exists, so it cannot be empty
    	n->places.push_back(n->sub[i]->places[0]);
        places_created++;
    }   

    sort(n->places.begin(), n->places.end());
}

/*
int main()
{
    return 0;
}
*/

// Adapted from http://www-128.ibm.com/developerworks/eserver/library/es-nweb.html

void log(int type, char *s1, char *s2, int num)
{
    int fd ;
    char logbuffer[1024];
    
    
    switch (type) {
    case ERROR: (void)snprintf(logbuffer, 1024, "ERROR: %s:%s Errno=%d exiting pid=%d",s1, s2, errno,getpid()); break;
    case SORRY: 
        (void)snprintf(logbuffer, 1023, "<HTML><BODY><H1>Tile Server Sorry: %s %s</H1></BODY></HTML>\r\n", s1, s2);
        (void)write(num,logbuffer,strlen(logbuffer));
        (void)snprintf(logbuffer, 1023, "SORRY: %s:%s",s1, s2); 
        break;
    case LOG: (void)snprintf(logbuffer, 1023, " INFO: %s:%s:%d",s1, s2,num); 
        break;
    }
    
    /* no checks here, nothing can be done a failure anyway */
    /* disable logging
    if((fd = open("tileserv.log", O_CREAT| O_WRONLY | O_APPEND,0644)) >= 0) {
        (void)write(fd,logbuffer,strlen(logbuffer)); 
        (void)write(fd,"\n",1);      
        (void)close(fd);
    }
    */
    if(type == ERROR || type == SORRY) exit(3);
}



/* this is a child web server process, so we can exit on errors */
void web(int fd, int hit)
{
    int k, j, file_fd, buflen, len;
    int x,y,z, tx,ty;
    long i, ret;
    node *n;
    static char buffer[ BUFSIZE + 1 ]; /* static so zero filled */
    char name2[300];
    
    
    ret = read( fd, buffer, BUFSIZE );   /* read Web request in one go */
    if( ret == 0 || ret == -1 ) {     /* read failure stop now */
        log(SORRY,"failed to read browser request","",fd);
    }
    if( ret > 0 && ret < BUFSIZE )    /* return code is valid chars */
        buffer[ret] = 0;          /* terminate the buffer */
    else buffer[0] = 0;
    
    for( i = 0; i < ret; i++ )      /* remove CF and LF characters */
        if(buffer[i] == '\r' || buffer[i] == '\n') buffer[i]='*';
    log(LOG,"request",buffer,hit);
    
    if( strncmp(buffer,"GET ",4) && strncmp(buffer,"get ",4) )
        log(SORRY,"Only simple GET operation supported",buffer,fd);
    
    for( i = 4; i < BUFSIZE; i++ ) { /* null terminate after the second space to ignore extra stuff */
        if(buffer[i] == ' ') { /* string is "GET URL " +lots of other stuff */
            buffer[i] = 0;
            break;
        }
    }
    
    if( sscanf( &buffer[0], "GET /%d_%d_%d\0", &y, &x, &z ) != 3 &&
        sscanf( &buffer[0], "GET /~dschwen/wma/commonsproxy/%d_%d_%d\0", &y, &x, &z ) != 3 ) 
    {
        log( SORRY, "failed to parse coordinate", "", fd );
    }
    
    (void)sprintf( buffer, "HTTP/1.0 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n" );
    (void)write( fd, buffer, strlen(buffer) );
    
    
    //Koordinate scannen und in einen textpuffer schreiben!
    n = getNode(y,x,z);
    len = 0;
    if(n==0) 
    { 
    	sprintf(&buffer[0],"\n\0");
    }
    else
    {
    	for( j = 0; j < 4 && j < n->places.size(); ++j )
        {
            ty = int(((90.0-n->places[j].lat)*zoomlevel[z]*128)/180.0) - (zoomlevel[z]-y-1)*128; 
            tx = int((n->places[j].lon*zoomlevel[z]*256)/360.0) - 128*x;

            // escape backslashes for the javascript parameter
	    k = 0;
            for( i = 0; i < n->places[j].name.length() && k < 298; ++i)
            {
             // if single quote then prepend backslash
             if( n->places[j].name[i] == 39 ) name2[k++] = 92; 
	     name2[k++] = n->places[j].name[i];
            }
            name2[k] = 0;

            if( n->places[j].dir < 16 )
            {
              len += snprintf( &buffer[len], BUFSIZE - len - 2, 
                               "<a href=\"javascript:wmaCommonsImage( '%s', %d, %d)\" class=\"cthumb dir dir%d\" style=\"top:%dpx; left:%dpx;\">"
                               "<img src=\"http://commons.wikimedia.org/w/thumb.php?w=%d&f=%s\"></a>\n\0", 
                               name2, n->places[j].imgw, n->places[j].imgh, n->places[j].dir, ty - 8, tx - 8, //circle is 15px x 15px
                               n->places[j].twidth, n->places[j].name.c_str() ) - 1;
            }
            else
            {
              len += snprintf( &buffer[len], BUFSIZE - len - 2, 
                               "<a href=\"javascript:wmaCommonsImage( '%s', %d, %d)\" class=\"cthumb\" style=\"top:%dpx; left:%dpx;\">"
                               "<img src=\"http://commons.wikimedia.org/w/thumb.php?w=%d&f=%s\"></a>\n\0", 
                               name2, n->places[j].imgw, n->places[j].imgh, ty - icon_off_y[0], tx - icon_off_x[0],
                               n->places[j].twidth, n->places[j].name.c_str() ) - 1;
            }
        }
    }
    
    log(LOG,"SEND",buffer,hit);
    (void)write(fd,&buffer[0],len+1);


#ifdef LINUX
    sleep(1);       /* to allow socket to drain */
#endif
    exit(1);
}

main(int argc, char **argv)
{
    int i, port, pid, listenfd, socketfd, hit;
    //size_t length;
    socklen_t length;
    char *str;

    int by,bx;


    if( argc < 3  || argc > 3 || !strcmp(argv[1], "-?") ) {
        (void)printf("hint: tileserv Port-Number coordinatefile.txt\n\n"
                     "\ttileserv is a small and very safe mini koordinate web server\n"
                     "\tExample: tileserv 8181 wp_koordinates-en.txt&\n\n");
        exit(0);
    }

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
    

    // Read coordinates

    for(int x=0; x<6; ++x)
        for(int y=0; y<3; ++y)
            base[y][x] = new node;
    
    string name,desc;
    int psize,n=0, imgw, imgh;
    unsigned int twidth, dir;
    float coord_lat, coord_lon;

    ifstream iFile(argv[2]);

    while(iFile.good())
    {
	psize=0; 
    	iFile >> coord_lon >> coord_lat >> psize >> twidth >> imgw >> imgh >> dir ;
        getline(iFile,name, '|');
        getline(iFile,name, '|');
        //getline(iFile,desc, '\n');
        getline(iFile,name, '\n');

        if(coord_lon<0) coord_lon+=360.0;

        by = int(((90.0+coord_lat)*3)/180.0);
        bx = int((coord_lon*6)/360.0);

        //cout << by  << ',' << bx << name << " (" << desc << ")" << endl;
        if( bx<6 && by<3 && bx>=0 && by>=0) 
          insertPlace( place( coord_lat, coord_lon, psize, twidth, imgw, imgh, name, dir ), by, bx );

        n++;
    }

    cout << nodes_created << " nodes created. " << places_created << " places created. " << n << " lines of input." << endl;

    for(int x=0; x<6; ++x)
        for(int y=0; y<3; ++y)
            recursePopulate(base[y][x]);

    cout << places_created << " total places created. " << endl;


    // Initialize Webserver

   
    static struct sockaddr_in cli_addr; /* static = initialised to zeros */
    static struct sockaddr_in serv_addr; /* static = initialised to zeros */
       
    /* Become deamon + unstopable and no zombies children (= no wait()) */
    if(fork()!= 0) return 0; /* parent returns OK to shell */
    
    (void)signal(SIGCLD, SIG_IGN); /* ignore child death */
    (void)signal(SIGHUP, SIG_IGN); /* ignore terminal hangups */
    (void)signal(SIGPIPE, SIG_IGN); /* ignore broken pipes */
    
    for(i=0;i<32;i++) (void)close(i);      /* close open files */
    
    (void)setpgrp();             /* break away from process group */
    
    log(LOG,"tileserv starting",argv[1],getpid());
    
    /* setup the network socket */
    if((listenfd = socket(AF_INET, SOCK_STREAM,0)) <0)
        log(ERROR, "system call","socket",0);
    
    port = atoi(argv[1]);
    if(port < 0 || port >60000)
        log(ERROR,"Invalid port number (try 1->60000)",argv[1],0);
    
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    serv_addr.sin_port = htons(port);
    
    if(bind(listenfd, (struct sockaddr *)&serv_addr,sizeof(serv_addr)) <0)
        log(ERROR,"system call","bind",0);
    
    if(listen(listenfd,64) <0)
        log(ERROR,"system call","listen",0);
    
    for(hit=1; ;hit++) {
        length = sizeof(cli_addr);
        if((socketfd = accept(listenfd, (struct sockaddr *)&cli_addr, &length)) < 0)
            log(ERROR,"system call","accept",0);
    
        if((pid = fork()) < 0) {
            log(ERROR,"system call","fork",0);
        }
        else {
            if(pid == 0) {  /* child */
                (void)close(listenfd);
                web(socketfd,hit); /* never returns */
            } else {        /* parent */
                (void)close(socketfd);
            }
        }
    }
}
