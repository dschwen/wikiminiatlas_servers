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

use DBI;
use DBD::mysql;
use URI::Escape;
use Encode qw(decode);
use Switch;
use IO::File;

require ("config.pl");

$bln = 0; 
while(<STDIN>)
{
    ( $coords, $title ) = split( /\|/, $_, 2 );
    $bl{$title} = $coords;
    $bln++;
}
print STDERR "$bln badlist entries read.\n";

$lang = $ARGV[0] || "en";
#$lang = $ARGV[0]."\n";

$dsn = "dbi:mysql:toolserver:sql:3306";
$db = DBI->connect( $dsn, $login_ds, $pass_ds,
                  { PrintError => 0}) || die $DBI::errstr;

$sth = $db->prepare( "select server from wiki where dbname='".$lang."wiki_p';" );
$sth->execute;
@row = $sth->fetchrow();
$sth->finish;
$db->disconnect;

$server = "sql-s".$row[0];
#$server = "sql-s2";

print STDERR "Connecting to $server\n";

#$dsn = "dbi:mysql:enwiki_p:sql-s1:3306";
$dsn = "dbi:mysql:".$lang."wiki_p:".$server.":3306";
$db = DBI->connect( $dsn, $login_ds, $pass_ds,
                  { PrintError => 1}) || die $DBI::errstr;

#@languages = ( "en", "de", "es", "fr", "it", "ja", "nl", "pl", "pt", "ru", "sv", "is", "zh", "ca", "no", "eo", "fi" );

#$titles = '';
#foreach( @languages )
#{
#	$handle{$_} = IO::File->new("> wp_coord_".$_.".txt");
#	$titles .= ', Titel_'.$_;
#}

$blacklist['en'] = "List of |History of |Geography of |Latitude and longitude of cities|Former toponyms of places in |Second Happy Time|Finnish exonyms for places in |Abbeys and priories in England|Wide Area Augmentation System|Australian places named by ";

$usstates = "Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|Florida|Georgia|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming";
$auterritories = "New South Wales|Victoria|South Australia|Queensland|Western Australia|Northern Territory";
$cdnterrprov = "Ontario|Quebec|Nova Scotia|New Brunswick|Manitoba|British Columbia|Prince Edward Island|Saskatchewan|Alberta|Newfoundland and Labrador|Northwest Territories|Yukon|Nunavut";
$country = "Democratic Republic of the Congo";

# boxing the compass
%btc = (
  "n" => 0, "nbe" => 0,
  "nne" => 1, "nebn" => 1, "nbne" => 1, 
  "ne" => 2, "nebe" => 2, "ebne" => 2,
  "ene" => 3, "ebn" => 3,
  "e" => 4, "ebs" => 4,
  "ese" => 5, "sebe" => 5, "ebse" => 5,
  "se" => 6, "sebs" => 6, "sbse" => 6,
  "sse" => 7, "sbe" => 7,
  "s" => 8, "sbw" => 8,
  "ssw" => 9, "swbs" => 9, "sbsw" => 9,
  "sw" => 10, "swbw" => 10, "wbsw" => 10,
  "wsw" => 11, "wbs" => 11,
  "w" => 12, "wbn" => 12,
  "wnw" => 13, "nwbw" => 13, "wbnw" => 13,
  "nw" => 14, "nwbn" => 14, "nbnw" => 14,
  "nnw" => 15, "nbw" => 15
);

$geohackurl = 'http://toolserver.org/~geohack/geohack.php?';
if( $lang eq 'nl' ) { 
    $geohackurl = 'http://www.nsesoftware.nl/wiki/maps.asp?'; 
}

$start = time();

if( $lang eq "commons" )
{
  #$query = "select /* SLOW_OK */ page_title, el_to, page_touched, GROUP_CONCAT( DISTINCT cl_to SEPARATOR '|'), img_width, img_height from externallinks, image, page left join categorylinks on page_id = cl_from where el_from = page_id and img_name = page_title and el_to like '".$geohackurl."%' and page_namespace=6 group by el_from";

    $query = "create temporary table u_dschwen.compics ( page_id int, page_title varchar(255), el_to blob, img_width int, img_height int )";
    $sth = $db->prepare( $query );
    $sth->execute;

    print STDERR "Parparing: fetching all images with coordinates.\n";
    $query = "insert /* SLOW_OK */ into u_dschwen.compics SELECT page_id, page_title, el_to, img_width, img_height from image, page, externallinks where img_name = page_title and page_namespace=6 and el_to like '".$geohackurl."%' and el_from = page_id"; 
    $sth = $db->prepare( $query );
    $sth->execute;

    $query = "select /* SLOW_OK */ page_title, el_to, 0, GROUP_CONCAT( DISTINCT cl_to SEPARATOR '|'), img_width, img_height from u_dschwen.compics left join categorylinks on page_id = cl_from group by page_id";
}
else
{
    $query = "select /* SLOW_OK */ page_title, el_to, page_touched, page_len from externallinks, page where el_from = page_id and el_to like '".$geohackurl."%' and page_namespace=0"; 

    @bl = split( /\|/, $blacklist[$lang] );
}

print STDERR "Starting query.\n";
print STDERR "$query\n";
print STDERR  $db->errstr;
$sth = $db->prepare( $query );
$sth->execute;
print STDERR  $db->errstr;
print STDERR "Query completed in in ", ( time() - $start ), " seconds.\n";

$maxdim = 48;

while( @row = $sth->fetchrow() ) 
{
  #( $lat, $lon, $pop, $psize, $type ) = @row[0..4];
  ( $title, $el, $date, $psize ) = @row[0..3];
	
  if( $el =~ /type:([a-zA-z0-9]+)/i ) { $type = $1; }
                                 else { $type = ""; }

  if( $el =~ /type:city\(([0-9,.]+)\)/i ) 
  {
    $pop = $1;
    $pop =~ s/,//g;
    $pop =~ s/\.//g;
    $pop = int($pop); 
  }
  else { $pop = 0; }

  $lat = "";
  $lon = "";
	
  $el2 = lc($el);
  $el2 =~ s/\s/_/g;

  if( $el2 =~ /params=([0-9n\-+\.]+)_([ns])_([0-9n\-+\.]+)_([weo])/ )
  {
    $lns = $2; $lwe = $4;
    $lat = $1 + 0.0; $lon = $3 + 0.0;
  }
  if( $el2 =~ /params=([0-9n\-+\.]+)_([0-9n\-+\.]+)_([ns])_([0-9n\-+\.]+)_([0-9n\-+\.]+)_([weo])/ )
  {
    $lns = $3; $lwe = $6;
    $lat = $1 + $2/60.0 + 0.0; $lon = $4 + $5/60.0 + 0.0;
  }
  if( $el2 =~ /params=([0-9n\-+\.]+)_([0-9n\-+\.]+)_([0-9n\-+\.]+)_([ns])_([0-9n\-+\.]+)_([0-9n\-+\.]+)_([0-9n\-+\.]+)_([weo])/ )
  {
    $lns = $4; $lwe = $8;
    $lat = $1 + $2/60.0 + $3/3600.0 + 0.0; $lon = $5 + $6/60.0 + $7/3600.0 + 0.0;
  }

  $url = $title;
  $title =~ s/_/ /g;

  # sift out non earth coordinates
  if( $el2 =~ /_globe:/ && !($el2 =~ /_globe:earth/) ) { $lat = ""; }


  # no object locations on commons please!
  if( $lang eq 'commons' && $el2 =~ /class:object/ ) { $lat = ""; }

  if( $lat ne "" &&  substr( lc($title), 0, 6 ) ne "liste " && substr( lc($title), 0, 11 ) ne "geschichte "  )
  {
    if( $lns eq "s" ) { $lat *= -1.0; }
    if( $lwe eq "w" ) { $lon *= -1.0; }

    switch(lc($type))
    {
      case "mountain"  { $style = 2; }
      case "country"   { $style = 3; }
      case "city"      { $style = 5; }
      case "event"      { $style = 10; }
      else { $style = 0; }
    }

    if($style==5 || $pop>1000)
    {
      if($pop<1000000)  { $style = 8; }
      if($pop<500000)   { $style = 7; }
      if($pop<100000)   { $style = 6; }
      if($pop<10000)    { $style = 5; }
      if($pop>=1000000) { $style = 9; }
    }

    $url =~ s/ /_/g;
    $url = uri_escape($title);
    $url =~ s/%2F/\//g; # unescape "/" for subpages

    # commons or one of the many wikipedias?
    if( $lang eq 'commons' ) 
    {
      # get thumbnail dimensions
      ( $width, $height ) = @row[4..5];
      if( $width >= $height )
      {
        $thumbw = $maxdim;
      }
      else
      {
        $thumbw = int( ( $maxdim * $width ) / $height );
      }

      # "punish" low res pictures with smaller thumbnails
      if( $width*$height < 1024*1024 ) { $thumbw = int( $thumbw / 2 ); }

      $catlist = $psize;
			
      # 4 points for each megapixel
      $psize = 4 * int( ( $width * $height ) / ( 1024 * 1024 ) );
      # additional points for awards
      @cats = split( /\|/, $catlist );
      foreach( @cats )
      {
        if( /^Featured_picture/i )   { $psize+=100; }
        if( /^Quality_images/i )       { $psize+=50; }
        if( /^Pictures_of_the_day/i ) { $psize+=20; }
      }
      
      # numerical heading
      if( $el2 =~ /heading:([+-0-9.]+)/ )
      {
        if( $1 > -360 && $1 < 360 )
        {
          $heading =  int(( (int($1)+360) % 360 ) / 27.0 + 0.5) % 16;
        }
        else
        {
          $heading = 18;
        }
      }
      # named heading
      elsif( $el2 =~ /heading:([noebsw]+)/ )
      {
        $bcode = $1;
        $bcode =~ s/o/e/g;
        if( defined $btc{$bcode} )
        {
          $heading = $btc{$bcode};
        }
        else
        {
          $heading = 18;
        }
      }
      else 
      {
        $heading = 17;
      }
			
      if( $title =~ /\.jpg$/i || $title =~ /\.jpeg$/ ) { print "$lon $lat $psize $thumbw $width $height $heading||$url\n"; }
    }
    else
    { 
      # explicit title given?
      if( $el =~ /\&title=([^\&]+)/ ) 
      { 
        $title2 = $1; 
        $title2 =~ s/\+/ /g;
        $title2 =~ s/%0A.*//g; #remove crap after linebreak
        $title2 = uri_unescape($title2);
        if( $title2 ne $title ) { $psize = 0; }
        #$psize = 0;
      }
      else
      {
        $title2 = $title;
      }

      #is the page badlisted (too many unnamed coords)
      $psize = 0 if( $bl{$title} > 1 );

      # take care of a few special cases
      if    ( $title2 =~ /^(.*) Township, .* County, ($usstates)$/ )         { $title2 = "$1 Twp."; }
      elsif ( $title2 =~ /^(.*) Township, ($usstates)$/ )                    { $title2 = "$1 Twp."; }
      elsif ( $title2 =~ /^(.*), ($usstates|$auterritories|$cdnterrprov|$country)$/ ) { $title2 = "$1"; }
      elsif ( $title2 =~ /^(.*) \(($usstates)\)$/ )                          { $title2 = "$1"; }
      elsif ( $title2 =~ /^(.*) \(i.* County, ($usstates)\)$/ )              { $title2 = "$1"; }
                            
      if( $title2 ne $title )
      {
        $title = "$title2|$title";
      }
    
      $blf = 0;
      foreach( @bl )
      {
        if( index($title, $_) == 0 ) { $blf = 1; }
      }

      if( !$blf ) 
      {   
        die "title '$title' too long!\n" if( length($title) > 254 );
        print "$lon $lat $pop $psize $style $title\n"; 
      }

    }
  }

#$sth->finish;
#$db->disconnect;

}

