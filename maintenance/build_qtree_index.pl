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
$auterritories = "New South Wales|Victoria|South Australia|Queensland|Western Australia|Northern Territory|Tasmania|Australian Capital Territory";
$cdnterrprov = "Ontario|Quebec|Nova Scotia|New Brunswick|Manitoba|British Columbia|Prince Edward Island|Saskatchewan|Alberta|Newfoundland and Labrador|Northwest Territories|Yukon|Nunavut";
$country = "Democratic Republic of the Congo";


#getting language ID
$lang = $ARGV[0] || "en";
my $langid = -1;
@all_lang = split(/,/,"ar,bg,ca,ceb,commons,cs,da,de,el,en,eo,es,et,eu,fa,fi,fr,gl,he,hi,hr,ht,hu,id,it,ja,ko,lt,ms,new,nl,nn,no,pl,pt,ro,ru,simple,sk,sl,sr,sv,sw,te,th,tr,uk,vi,vo,war,zh,af,als,be,bpy,fy,ga,hy,ka,ku,la,lb,lv,mk,ml,nds,nv,os,pam,pms,ta,vec,kk,ilo,ast,uz,oc,sh,tl,sco,kn");
for( $i = 0; $i<@all_lang; $i++ ) {
  $langid = $i if( lc($lang) eq lc($all_lang[$i]) );
}
print "langid=$langid\n";
die "unsupported language" if( $langid < 0 );

my $database = $lang . "wiki_p";
my $host = $lang . "wiki.labsdb";

my $db = DBI->connect(
  "DBI:mysql:database=$database;host=$host;mysql_use_result=0;mysql_read_default_file=" . getpwuid($<)->dir . "/replica.my.cnf",
  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

print "Connected.\n";

my $wmadatabase = "p50380g50921__wma_p";
my $gheldatabase = "p50380g50921__ghel_p";

#create temporary blacklist table in $wmadatabase
if( $langid != 4 ) {
  $query = "CREATE TEMPORARY TABLE $wmadatabase.blacklist (gc_from INT, cpp INT, cdn INT, dnf FLOAT);";
  $sth = $db->prepare( $query );
  $rows = $sth->execute;
  $query = "INSERT /* SLOW_OK */ INTO $wmadatabase.blacklist SELECT gc_from, count(*) AS cpp, COUNT(DISTINCT gc_name) AS cdn, COUNT(DISTINCT gc_name)/count(*) AS dnf FROM $gheldatabase.coord_${lang}wiki c GROUP BY gc_from HAVING dnf<0.9 AND cpp>4;";
  $sth = $db->prepare( $query ) or die;
  $rows = $sth->execute or die;
  print "Found $rows blacklisted articles.\n";
  $query = "CREATE INDEX /* SLOW_OK */ from_index ON $wmadatabase.blacklist (gc_from);";
  $sth = $db->prepare( $query ) or die;
  $rows = $sth->execute or die;
  print "Index created.\n";
}

$rev = $ARGV[1]+0;
$maxzoom = 14;

undef @insert;

#    $query = "create temporary table $wmadatabase.compics ( page_id int, page_title varchar(255), el_to blob, img_width int, img_height int )";
#    110     $sth = $db->prepare( $query );
#    111     $sth->execute;
#    112
#    113     print STDERR "Parparing: fetching all images with coordinates.\n";
#    114     $query = "insert /* SLOW_OK */ into $wmadatabase.compics SELECT page_id, page_title, el_to, img_width, img_height from image, page, externallinks where im    g_name = page_title and page_namespace=6 and el_to like '".$geohackurl."%' and el_from = page_id";
#    115     $sth = $db->prepare( $query );
#    116     $sth->execute;
#    117
#    118     $query = "select /* SLOW_OK */ page_title, el_to, 0, GROUP_CONCAT( DISTINCT cl_to SEPARATOR '|'), img_width, img_height from $wmadatabase.compics left joi    n categorylinks on page_id = cl_from group by page_id";
#    119 }
#    12


$start = time();
$fac = ((1<<$maxzoom)*3)/180.0;
if( $langid == 4 ) {
  $query = "CREATE TEMPORARY TABLE $wmadatabase.compics ( pid INT, lat DOUBLE(11,8), lon DOUBLE(11,8), title VARCHAR(255), head FLOAT, globe ENUM('','Mercury','Ariel','Phobos','Deimos','Mars','Rhea','Oberon','Europa','Tethys','Pluto','Miranda','Titania','Phoebe','Enceladus','Venus','Moon','Hyperion','Triton','Ceres','Dione','Titan','Ganymede','Umbriel','Callisto','Jupiter','Io','Earth','Mimas','Iapetus') )";
  $sth = $db->prepare( $query );
  $sth->execute;

  print STDERR "Parparing: fetching all images with camera coordinates.\n";
$query = <<QEND
  INSERT INTO  $wmadatabase.compics SELECT /* SLOW_OK */
    page_id, gc_lat, gc_lon, page_title, gc_head,
    CASE gc_globe WHEN '' THEN 'Earth' ELSE gc_globe END
  FROM $gheldatabase.coord_${lang}wiki c, page
    WHERE page_namespace=6
      AND c.gc_from=page_id
      AND gc_lat<=90.0 AND gc_lat>=-90.0
      AND ( c.gc_type="camera" OR c.gc_type IS NULL )
QEND
;

  $sth = $db->prepare( $query ) or die;
  $rows = $sth->execute or die "Error filling prep table: ".$db->errstr;
  print "PrepQuery completed in in ", ( time() - $start ), " seconds. $rows rows.\n";

  $query = "CREATE INDEX pageid ON $wmadatabase.compics (pid)";
  $sth = $db->prepare( $query );
  $sth->execute or die "Error building index: ".$db->errstr;

  $query = "CREATE INDEX pagetit ON $wmadatabase.compics (title(10))";
  $sth = $db->prepare( $query );
  $sth->execute or die "Error building index: ".$db->errstr;

$query = <<QEND
  SELECT /* SLOW_OK */
    pid, lat, lon, img_width, img_height, head, title, t.id, globe,
    GROUP_CONCAT( DISTINCT cl_to SEPARATOR '|')
  FROM  image, $wmadatabase.compics
    LEFT JOIN categorylinks ON pid = cl_from
    LEFT JOIN $wmadatabase.wma_tile t ON t.z=$maxzoom
      AND t.x=FLOOR( (lon-FLOOR(lon/360)*360) * $fac ) AND t.y=FLOOR( (lat+90.0) * $fac )
    WHERE title = img_name
    GROUP BY pid
QEND
;
} else {
$query = <<QEND
  SELECT /* SLOW_OK */
    page_id, gc_lat, gc_lon, page_len, gc_size, gc_type,
    CASE WHEN gc_primary=1 THEN page_title ELSE gc_name END, t.id, gc_primary,
    CASE gc_globe WHEN '' THEN 'Earth' ELSE gc_globe END
  FROM page, $gheldatabase.coord_${lang}wiki c
    LEFT JOIN $wmadatabase.blacklist b ON b.gc_from=c.gc_from
    LEFt JOIN $wmadatabase.wma_tile t ON t.z=$maxzoom
      AND t.x=FLOOR( (gc_lon-FLOOR(gc_lon/360)*360) * $fac ) AND t.y=FLOOR( (gc_lat+90.0) * $fac )
    WHERE page_namespace=0 AND c.gc_from=page_id
      AND gc_lat<=90.0 AND gc_lat>=-90.0
      AND b.gc_from IS NULL;
QEND
;
}

print "Starting query.\n";
print STDERR  $db->errstr;
$sth = $db->prepare( $query ) or die;
$rows = $sth->execute or die;
print STDERR  $db->errstr;
print "Query completed in in ", ( time() - $start ), " seconds. $rows rows.\n";

my $db2 = DBI->connect(
  "DBI:mysql:database=$wmadatabase;host=$host;mysql_multi_statements=1;mysql_read_default_file=" . getpwuid($<)->dir . "/replica.my.cnf",
  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

$query = "DELETE /* SLOW_OK */ c.*, l.* FROM wma_connect c, wma_label l WHERE c.label_id = l.id AND c.rev='$rev' AND l.lang_id='$langid';";
$sth2 = $db2->prepare( $query ) or die;
$rows = $sth2->execute or die;
print "Delete $rows label connectors from previous run.\n" if( $rows > 0 );

while( @row = $sth->fetchrow() )
{
  if( $langid == 4 ) {
    ( $pageid, $lat, $lon, $imgwidth, $imgheight, $heading, $name, $tileid, $globe, $catlist ) = @row[0..9];
    next if( !( $name =~ /\.jpg$/i || $name =~ /\.jpeg$/i ) );
    $style = -1;

    # 4 points for each megapixel
    $weight = 4 * int( ( $imgwidth * $imgheight ) / ( 1024 * 1024 ) );
    $style = -2 if( $weight == 0 );

    # additional points for awards
    @cats = split( /\|/, $catlist );
    foreach( @cats )
    {
      if( /^Featured_picture/i )   { $weight+=100; }
      if( /^Quality_images/i )      { $weight+=50; }
      if( /^Valued_images/i )       { $weight+=30; }
      if( /^Pictures_of_the_day/i ) { $weight+=20; }
    }

    # numerical heading
    if( $heading ne '' && $heading > -360 && $heading < 360 ) {
      $heading =  int(( (int($heading)+360) % 360 ) / 22.5 + 0.5) % 16;
      $weight += 10;
    } else {
      $heading = 18;
    }

    $name = $imgwidth.'|'.$imgheight.'|'.$heading; #.'|'.$name
    #print "$name\n"
  } else {
    ( $pageid, $lat, $lon, $weight, $pop, $type, $name, $tileid, $primary, $globe ) = @row[0..9];
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
    $weight = ( int($weight) + $pop/20 - length($name)**2 ) * $primary;
  }

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

    # make sure the connection is there
    #$db2 ||= DBI->connect(
    #  "DBI:mysql:database=$wmadatabase;host=$host;mysql_multi_statements=1;mysql_read_default_file=" . getpwuid($<)->dir . "/.my.cnf",
    #  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

    $sth2 = $db2->prepare( $query ) or die;
    $rows = $sth2->execute or die;
    $tileid = $db2->{ q{mysql_insertid} };
  }

  # insert labels
  push(@insert,"CALL InsertLabel('$pageid','$langid',".($db2->quote($name)).",'$style','$globe','$lat','$lon','$weight','$tileid','$rev')");
  if( scalar(@insert) >= 10 ) {
    $query = join(';',@insert) . ";";

    # make sure the connection is there
    #while(1) {
    #  $db2 ||= DBI->connect(
    #    "DBI:mysql:database=$wmadatabase;host=$host;mysql_multi_statements=1;mysql_read_default_file=" . getpwuid($<)->dir . "/.my.cnf",
    #    undef, undef) or die "Error: $DBI::err, $DBI::errstr";

      $sth2 = $db2->prepare( $query ) or next;
      $sth2->execute or next;
      #  last;
      #}
    undef @insert;
  }
}

if( scalar(@insert) > 0 ) {
  $query = join(';',@insert) . ";";

  # make sure the connection is there
  #while(1) {
  #  $db2 ||= DBI->connect(
  #    "DBI:mysql:database=$wmadatabase;host=$host;mysql_multi_statements=1;mysql_read_default_file=" . getpwuid($<)->dir . "/.my.cnf",
  #    undef, undef) or die "Error: $DBI::err, $DBI::errstr";

    $sth2 = $db2->prepare( $query ) or next;
    $sth2->execute or next;
    #  last;
  #}
  undef @insert;
}
