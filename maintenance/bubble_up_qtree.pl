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
@all_lang = split(/,/,"ar,bg,ca,ceb,commons,cs,da,de,el,en,eo,es,et,eu,fa,fi,fr,gl,he,hi,hr,ht,hu,id,it,ja,ko,lt,ms,new,nl,nn,no,pl,pt,ro,ru,simple,sk,sl,sr,sv,sw,te,th,tr,uk,vi,vo,war,zh,af,als,be,bpy,fy,ga,hy,ka,ku,la,lb,lv,mk,ml,nds,nv,os,pam,pms,ta,vec,kk,ilo,ast,uz,oc,sh,tl");
for( $i = 0; $i<@all_lang; $i++ ) {
  $langid = $i if( lc($lang) eq lc($all_lang[$i]) );
}
print "langid=$langid\n";
die "unsupported language" if( $langid < 0 );

$maxzoom = 14;
$rev = $ARGV[1]+0;


my $wmadatabase = "p50380g50921__wma_p";
my $host = $lang . "wiki.labsdb";

my $db = DBI->connect(
  "DBI:mysql:database=$wmadatabase;host=$host;mysql_use_result=0;mysql_read_default_file=" . getpwuid($<)->dir . "/replica.my.cnf",
  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

print "Connected.\n";
      

for( $zoom = $maxzoom-1; $zoom >= 0; $zoom-- ) 
{
  print "Zoom $zoom\n";
  $zoompo = $zoom +1;

  $query = <<"  QEND"
/* bubble_up_qtree SLOW_OK */
DELETE QUICK c.* 
FROM wma_connect c, wma_label l, wma_tile t 
WHERE c.label_id = l.id AND c.tile_id=t.id AND c.rev='$rev' 
AND l.lang_id='$langid' AND t.z='$zoom';
  QEND
  ;
  #print "$query\n";
  $sth = $db->prepare( $query );
  $rows = $sth->execute;
  print "Delete $rows connectors in zoom $zoom from previous run.\n" if( $rows > 0 );

  $start = time();
  $query = <<"  QEND"
/* bubble_up_qtree SLOW_OK */
INSERT INTO wma_tile (x,y,z,xh,yh)
SELECT DISTINCT  t.xh, t.yh, '$zoom', FLOOR(t.xh/2), FLOOR(t.yh/2)
FROM wma_tile t 
LEFT JOIN wma_tile t2 ON t2.x=t.xh AND t2.y=t.yh AND t2.z=$zoom
WHERE t.z='$zoompo' AND t2.id IS NULL;
  QEND
  ;
  #print "$query\n";
  $sth = $db->prepare( $query );
  $rows = $sth->execute;
  print " inserted $rows missing tile entries.\n" if( $rows > 0 );

  $query = <<"  QEND"
/* bubble_up_qtree SLOW_OK */
INSERT INTO wma_connect (tile_id,label_id,rev)
SELECT tileid, label_id, '$rev'
FROM (
  SELECT c.tile_id AS tid, c.label_id, t2.id AS tileid, l.globe 
  FROM wma_connect c, wma_label l, wma_tile t, wma_tile t2 
  WHERE t.id = c.tile_id AND l.id = c.label_id AND t.z='$zoompo' AND c.rev='$rev' AND 
  l.lang_id='$langid' AND t2.z='$zoom' AND t2.x=t.xh AND t2.y=t.yh
  ORDER BY t.id,l.globe,l.weight DESC
) AS low_level_tiles
GROUP BY tid, globe;
  QEND
  ;
  #print "$query\n";
  $sth = $db->prepare( $query ) or die "error preparing bubble up query";
  $sth->execute;

  print " bubbled x out of x in ", ( time() - $start ), " seconds.\n";
}

exit;

# old complicated method
if(0) {
  $query = <<"  QEND"
/* bubble_up_qtree SLOW_OK */
    SELECT /* SLOW_OK */ c.tile_id, c.label_id, t2.id, l.globe 
      FROM wma_connect c, wma_label l, wma_tile t, wma_tile t2 
      WHERE t.id = c.tile_id AND l.id = c.label_id AND t.z='$zoompo' AND c.rev='$rev' AND 
            l.lang_id='$langid' AND t2.z='$zoom' AND t2.x=t.xh AND t2.y=t.yh
      ORDER BY t.id,l.globe,l.weight DESC;
  QEND
  ;
  #print "$query\n";
  $sth = $db->prepare( $query );
  $sth->execute;

  $lastuid = '';
  $nbubble = 0; $ntotal = 0;
  undef @insert;
  while( @row = $sth->fetchrow() ) 
  {
    $ntotal++;
    ( $tid, $labelid, $tileid, $globe ) = @row[0..3];
    $uid = $tid.'|'.$globe;
    next if( $uid eq $lastuid );
    $lastuid = $uid;
    $nbubble++;

    # insert at zoom
    $query = "INSERT INTO wma_connect (tile_id,label_id,rev) VALUES ('$tileid','$labelid','$rev');";
    push(@insert,"('$tileid','$labelid','$rev')");
    if( scalar(@insert) >= 100 ) {
      $query = "INSERT INTO wma_connect (tile_id,label_id,rev) VALUES " . join(',',@insert) . ";";
      $sth2 = $db->prepare( $query );
      $rows = $sth2->execute;
      undef @insert;
    }
  }

  if( scalar(@insert) > 0 ) {
    $query = "INSERT INTO wma_connect (tile_id,label_id,rev) VALUES " . join(',',@insert) . ";";
    $sth2 = $db->prepare( $query );
    $rows = $sth2->execute;
  }
 
  print " bubbled $nbubble out of $ntotal\n";
}
