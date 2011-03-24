#!/usr/bin/perl

 #######################################################################
 #
 # Article coordinate extrator (c) 2009-2010 by Daniel Schwen
 #
 #
 # This program is free software; you can redistribute it and/or modify
 # it under the terms of the GNU General Public License as published by
 # the Free Software Foundation; either version 3 of the License, or (at
 # your option) any later version.
 #
 # This program is distributed in the hope that it will be useful, but
 # WITHOUT ANY WARRANTY; without even the implied warranty of
 # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 # General Public License for more details.
 #
 # You should have received a copy of the GNU General Public License along
 # with this program; if not, write to the Free Software Foundation, Inc.,
 # 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.
 #
 #######################################################################

use User::pwent;
use DBI;
use DBD::mysql;
use URI::Escape;
use Encode qw(decode);
use Switch;
use IO::File;

$bln = 0; 
while(<STDIN>)
{
    ( $coords, $title ) = split( /\|/, $_, 2 );
    $bl{$title} = $coords;
    $bln++;
}
print STDERR "$bln badlist entries read.\n";

$lang = $ARGV[0] || "en";

#getting language ID
my $lang_id = -1;
@all_lang = split(/,/,"ar,bg,ca,ceb,commons,cs,da,de,el,en,eo,es,et,eu,fa,fi,fr,gl,he,hi,hr,ht,hu,id,it,ja,ko,lt,ms,new,nl,nn,no,pl,pt,ro,ru,simple,sk,sl,sr,sv,sw,te,th,tr,uk,vi,vo,war,zh");
for( $i = 0; $i<@all_lang; $i++ ) {
  $langid = $i if( lc($lang) eq lc($all_lang[$i]) );
}
print "langid=$langid\n";
die "unsupported language" if( $langid < 0 );

my $database = $lang . "wiki_p";
my $host = $lang . "wiki-p.userdb.toolserver.org";
my $db = DBI->connect(
  "DBI:mysql:database=$database;host=$host;mysql_read_default_file=" . getpwuid($<)->dir . "/.my.cnf",
  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

my $userdatabase = "u_dschwen";
my $db2 = DBI->connect(
  "DBI:mysql:database=$userdatabase;host=$host;mysql_read_default_file=" . getpwuid($<)->dir . "/.my.cnf",
  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

print "Connected.\n";
  
$query = "DELETE FROM wma_label WHERE rev='$rev';";
$sth2 = $db2->prepare( $query );
$rows = $sth2->execute;
print "Delete $rows labels from previous run.\n";

$start = time();
$query = "SELECT /* SLOW_OK */  page_title, page_id, gc_lat, gc_lon, page_len+gc_size/20 FROM page, u_dispenser_p.coord_".$lang."wiki WHERE page_namespace=0 AND gc_from = page_id AND ( gc_globe ='' or gc_globe = 'earth')"; 

print STDERR "Starting query.\n";
print STDERR "$query\n";
print STDERR  $db->errstr;
$sth = $db->prepare( $query );
$sth->execute;
print STDERR  $db->errstr;
print STDERR "Query completed in in ", ( time() - $start ), " seconds.\n";

$maxzoom = 13;
$rev = 0;

while( @row = $sth->fetchrow() ) 
{
  ( $title, $pageid, $lat, $lon, $weight ) = @row[0..4];
  $pop = int($pop);

  #is the page badlisted (too many unnamed coords)
  next if( $bl{$title} > 1 );

  # calculate tile coordinates at maxzoom
  $y = int( ( 90.0 + $lat ) / 180.0 * ((1<<$maxzoom)*3) );
  $x = int( $lon / 360.0 * ((1<<$maxzoom)*3) * 2 );

  # did we already insert a tile?
  $query = "SELECT id FROM wma_tile WHERE z='$maxzoom' AND x='$x' AND y='$y' AND rev='$rev';";
  $sth2 = $db2->prepare( $query );
  $rows = $sth2->execute;
  if( $rows == 0 ) {
    $query = "INSERT INTO wma_tile (x,y,z,rev) VALUES ('$x','$y','$maxzoom','$rev');";
    $sth2 = $db2->prepare( $query );
    $rows = $sth2->execute;
    $tileid = $db2->{ q{mysql_insertid} };
  } else {
    die "ambiguous tile" if( $rows > 1 );
    ( $tileid ) = $sth2->fetchrow;
  }

  # insert at maxzoom
  $query = "INSERT INTO wma_label (tile_id,page_id,weight,lang_id,rev) VALUES ('$tileid','$pageid','$weight','$langid','$rev');";
  $sth2 = $db2->prepare( $query );
  $rows = $sth2->execute;
}

