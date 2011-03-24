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

$lang = $ARGV[0] || "en";

#getting language ID
my $langid = -1;
@all_lang = split(/,/,"ar,bg,ca,ceb,commons,cs,da,de,el,en,eo,es,et,eu,fa,fi,fr,gl,he,hi,hr,ht,hu,id,it,ja,ko,lt,ms,new,nl,nn,no,pl,pt,ro,ru,simple,sk,sl,sr,sv,sw,te,th,tr,uk,vi,vo,war,zh");
for( $i = 0; $i<@all_lang; $i++ ) {
  $langid = $i if( lc($lang) eq lc($all_lang[$i]) );
}
print "langid=$langid\n";
die "unsupported language" if( $langid < 0 );

$maxzoom = 13;
$rev = 0;

my $userdatabase = "u_dschwen";
my $host = $lang . "wiki-p.userdb.toolserver.org";
my $db = DBI->connect(
  "DBI:mysql:database=$userdatabase;host=$host;mysql_read_default_file=" . getpwuid($<)->dir . "/.my.cnf",
  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

print "Connected.\n";
  
for( $zoom = $maxzoom-1; $zoom >= 0; $zoom-- ) 
{
  print "Zoom $zoom\n";

  $query = "DELETE l.* FROM wma_label l, wma_tile t WHERE l.lang_id='$langid' AND l.rev='$rev' AND t.rev='$rev' AND t.z='$zoom';";
  $sth = $db->prepare( $query );
  $rows = $sth->execute;
  print "Delete $rows labels in zoom $zoom from previous run.\n" if( $rows > 0 );

  $start = time();
  $query = "SELECT /* SLOW_OK */  FLOOR(x/2) as x2, FLOOR(y/2) as y2, t.id, l.weight, page_id FROM wma_label l, wma_tile t WHERE t.id = l.tile_id AND t.z='".($zoom+1)."' AND l.rev='$rev' AND t.rev='$rev' AND lang_id='$langid' ORDER BY x2,y2,l.weight;"; 
  $sth = $db->prepare( $query );
  $sth->execute;

  $lasttid = -1;
  $nbubble = 0; $ntotal = 0;
  while( @row = $sth->fetchrow() ) 
  {
    $ntotal++;
    ( $x, $y, $tid, $weight, $pageid ) = @row[0..4];
    next if( $tid == $lasttid );
    $lasttid = $tid;
    $nbubble++;

    # did we already insert a tile?
    $query = "SELECT id FROM wma_tile WHERE z='$zoom' AND x='$x' AND y='$y' AND rev='$rev';";
    $sth2 = $db->prepare( $query );
    $rows = $sth2->execute;
    if( $rows == 0 ) {
      $query = "INSERT INTO wma_tile (x,y,z,rev) VALUES ('$x','$y','$zoom','$rev');";
      $sth2 = $db->prepare( $query );
      $rows = $sth2->execute;
      $tileid = $db->{ q{mysql_insertid} };
    } else {
      die "ambiguous tile" if( $rows > 1 );
      ( $tileid ) = $sth2->fetchrow;
    }

    # insert at zoom
    $query = "INSERT INTO wma_label (tile_id,page_id,weight,lang_id,rev) VALUES ('$tileid','$pageid','$weight','$langid','$rev');";
    $sth2 = $db->prepare( $query );
    $rows = $sth2->execute;
  }
 
  print " bubbled $nbubble out of $ntotal\n";
}
