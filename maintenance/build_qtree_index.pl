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

$usstates = "Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|Florida|Georgia|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming";
$auterritories = "New South Wales|Victoria|South Australia|Queensland|Western Australia|Northern Territory";
$cdnterrprov = "Ontario|Quebec|Nova Scotia|New Brunswick|Manitoba|British Columbia|Prince Edward Island|Saskatchewan|Alberta|Newfoundland and Labrador|Northwest Territories|Yukon|Nunavut";
$country = "Democratic Republic of the Congo";


#getting language ID
$lang = $ARGV[0] || "en";
my $langid = -1;
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
  "DBI:mysql:database=$userdatabase;host=$host;mysql_multi_statements=1;mysql_read_default_file=" . getpwuid($<)->dir . "/.my.cnf",
  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

print "Connected.\n";
  
#create temporary blacklist table in u_dschwen
$query = "CREATE TEMPORARY TABLE u_dschwen.blacklist (gc_from INT, cpp INT, cdn INT, dnf FLOAT);";
$sth = $db->prepare( $query );
$rows = $sth->execute;
$query = "INSERT INTO u_dschwen.blacklist SELECT gc_from, count(*) AS cpp, COUNT(DISTINCT gc_name) AS cdn, COUNT(DISTINCT gc_name)/count(*) AS dnf FROM u_dispenser_p.coord_${lang}wiki c GROUP BY gc_from HAVING dnf<0.9 AND cpp>4;";
$sth = $db->prepare( $query );
$rows = $sth->execute;
print "Found $rows blacklisted articles.\n";
$query = "CREATE INDEX from_index ON u_dschwen.blacklist (gc_from);";
$sth = $db->prepare( $query );
$rows = $sth->execute;
print "Index created.\n";

$rev = 0;
$maxzoom = 13;

$query = "DELETE c.*, l.* FROM wma_connect c, wma_label l WHERE c.label_id = l.id AND c.rev='$rev' AND l.lang_id='$langid';";
$sth2 = $db2->prepare( $query );
$rows = $sth2->execute;
print "Delete $rows label connectors from previous run.\n" if( $rows > 0 );

$start = time();
$fac = ((1<<$maxzoom)*3)/180.0;
$query = <<QEND
  SELECT /* SLOW_OK */ 
    page_title, page_id, gc_lat, gc_lon, page_len, gc_size, gc_type,
    CASE WHEN gc_primary=1 THEN page_title ELSE gc_name END, t.id
  FROM page, u_dispenser_p.coord_${lang}wiki c 
    LEFT JOIN u_dschwen.blacklist b ON b.gc_from=c.gc_from
    LEFt JOIN u_dschwen.wma_tile t ON t.z=$maxzoom 
      AND t.x=FLOOR( (gc_lon-FLOOR(gc_lon/360)*360) * $fac ) AND t.y=FLOOR( (gc_lat+90.0) * $fac )
    WHERE page_namespace=0 AND c.gc_from=page_id AND ( gc_globe ='' or gc_globe = 'earth') 
      AND gc_lat<=90.0 AND gc_lat>=-90.0
      AND b.gc_from IS NULL;
QEND
;
print "Starting query.\n";
print STDERR  $db->errstr;
$sth = $db->prepare( $query );
$sth->execute;
print STDERR  $db->errstr;
print "Query completed in in ", ( time() - $start ), " seconds.\n";

while( @row = $sth->fetchrow() ) 
{
  ( $title, $pageid, $lat, $lon, $weight, $pop, $type, $name, $tileid ) = @row[0..8];
  $pop = int($pop);
  $name =~ s/_/ /g;

  switch(lc($type))
  {
    case "mountain"  { $style = 2; }
    case "country"   { $style = 3; }
    case "city"      { 
      if($pop<1000000)  { $style = 8; }
      if($pop<500000)   { $style = 7; }
      if($pop<100000)   { $style = 6; }
      if($pop<10000)    { $style = 5; }
      if($pop>=1000000) { $style = 9; }
    }
    case "event"      { $style = 10; }
    else { $style = 0; }
  }

  # take care of a few special cases
  if    ( $name =~ /^(.*) Township, .* County, ($usstates)$/ )         { $name = "$1 Twp."; }
  elsif ( $name =~ /^(.*) Township, ($usstates)$/ )                    { $name = "$1 Twp."; }
  elsif ( $name =~ /^(.*), ($usstates|$auterritories|$cdnterrprov|$country)$/ ) { $name = "$1"; }
  elsif ( $name =~ /^(.*) \(($usstates)\)$/ )                          { $name = "$1"; }
  elsif ( $name =~ /^(.*) \(i.* County, ($usstates)\)$/ )              { $name = "$1"; }
  
  # calculate final weight
  $weight = int($weight) + $pop/20 - length($name)**2;

  # calculate tile coordinates at maxzoom
  $y = int( ( 90.0 + $lat ) / 180.0 * ((1<<$maxzoom)*3) );
  $lon += 360.0 if( $lon < 0 );
  next if( ( $lon < 0.0 ) || ( $lon > 360.0 ) );
  $x = int( $lon / 360.0 * ((1<<$maxzoom)*3) * 2 );

  # did we already insert a tile?
  if( $tileid == 0 ) {
    $xh=int($x/2);
    $yh=int($y/2);
    $query = "INSERT INTO wma_tile (x,y,z,xh,yh) VALUES ('$x','$y','$maxzoom','$xh','$yh');";
    $sth2 = $db2->prepare( $query );
    $rows = $sth2->execute;
    $tileid = $db2->{ q{mysql_insertid} };
  } 

  # insert label 
  $query = "CALL InsertLabel('$pageid','$langid',".($db2->quote($name)).",'$style','$lat','$lon','$weight','$tileid','$rev');";
  $sth2 = $db2->prepare( $query );
  $rows = $sth2->execute;
}
