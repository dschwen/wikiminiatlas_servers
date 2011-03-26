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


$usstates = "Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|Florida|Georgia|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming";
$auterritories = "New South Wales|Victoria|South Australia|Queensland|Western Australia|Northern Territory";
$cdnterrprov = "Ontario|Quebec|Nova Scotia|New Brunswick|Manitoba|British Columbia|Prince Edward Island|Saskatchewan|Alberta|Newfoundland and Labrador|Northwest Territories|Yukon|Nunavut";
$country = "Democratic Republic of the Congo";


#getting language ID
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
  "DBI:mysql:database=$userdatabase;host=$host;mysql_read_default_file=" . getpwuid($<)->dir . "/.my.cnf",
  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

print "Connected.\n";
  
$rev = 0;

$query = "DELETE c.*, l.* FROM wma_connect c, wma_label l WHERE c.label_id = l.id AND c.rev='$rev' AND l.lang_id='$langid';";
print "$query\n";
$sth2 = $db2->prepare( $query );
$rows = $sth2->execute;
print "Delete $rows label connectors from previous run.\n";

$start = time();
$query = "SELECT /* SLOW_OK */ page_title, page_id, gc_lat, gc_lon, page_len, gc_size, gc_type, CASE WHEN gc_primary=1 THEN page_title ELSE gc_name 
END FROM page, u_dispenser_p.coord_".$lang."wiki WHERE page_namespace=0 AND gc_from = page_id AND ( gc_globe ='' or gc_globe = 'earth')"; 

print STDERR "Starting query.\n";
print STDERR "$query\n";
print STDERR  $db->errstr;
$sth = $db->prepare( $query );
$sth->execute;
print STDERR  $db->errstr;
print STDERR "Query completed in in ", ( time() - $start ), " seconds.\n";

$maxzoom = 13;

# lock for writing
$query = "LOCK TABLES wma_connect WRITE, wma_label WRITE, wma_tile WRITE;";
$sth2 = $db2->prepare( $query );
$rows = $sth2->execute;

while( @row = $sth->fetchrow() ) 
{
  ( $title, $pageid, $lat, $lon, $weight, $pop, $type, $name ) = @row[0..5];
  $pop = int($pop);
  $weight = int($weight) + $pop/20;
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
  
  #is the page badlisted (too many unnamed coords)
  next if( $bl{$title} > 1 );

  # calculate tile coordinates at maxzoom
  next if( ( $lat > 90.0 ) || ( $lat < -90.0 ) );
  $y = int( ( 90.0 + $lat ) / 180.0 * ((1<<$maxzoom)*3) );
  $lon += 360.0 if( $lon < 0 );
  next if( ( $lon < 0.0 ) || ( $lon > 360.0 ) );
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

  # insert label 
  $query = "INSERT INTO wma_label (page_id,lang_id,name,style,lat,lon,weight) VALUES ('$pageid','$langid',".($db2->quote($name)).",'$style','$lat','$lon','$weight');";
  $sth2 = $db2->prepare( $query );
  $rows = $sth2->execute;
  $labelid = $db2->{ q{mysql_insertid} };

  # insert connect at maxzoom
  $query = "INSERT INTO wma_connect (tile_id,label_id,rev) VALUES ('$tileid','$labelid','$rev');";
  $sth2 = $db2->prepare( $query );
  $rows = $sth2->execute;
}

# unlock
$query = "UNLOCK TABLES;";
$sth2 = $db2->prepare( $query );
$rows = $sth2->execute;

