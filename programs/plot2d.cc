/************************************************************************
 *
 * 2D bitmap plotter (c) 2009-2010 by Daniel Schwen
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

int main( int argc, char *argv[] )
{
	if( argc != 3 ) return 1;

	int w = atoi( argv[1] );
	int h = atoi( argv[2] );
	int x, y;

	unsigned char *map = (unsigned char *) calloc( w * h, 1 );

	while( !feof(stdin) )
	{
		if( fscanf( stdin, "%d %d\n", &x, &y ) == 2 )
			if( x < w && y < h && x >= 0 && y >= 0 ) map[ x + w*y ] = 255;
	}

	fwrite( map, 1, w*h, stdout );
	return 0;
}
