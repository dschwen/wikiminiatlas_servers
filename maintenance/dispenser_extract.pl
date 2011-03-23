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

my $database = $lang . "wiki_p";
my $host = $lang . "wiki-p.rrdb.toolserver.org";
my $db = DBI->connect(
  "DBI:mysql:database=$database;host=$host;mysql_read_default_file=" . getpwuid($<)->dir . "/.my.cnf",
  undef, undef) or die "Error: $DBI::err, $DBI::errstr";

$blacklist['en'] = "List of |History of |Geography of |Latitude and longitude of cities|Former toponyms of places in |Second Happy Time|Finnish exonyms for places in |Abbeys and priories in England|Wide Area Augmentation System|Australian places named by ";

$usstates = "Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|Florida|Georgia|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming";
$auterritories = "New South Wales|Victoria|South Australia|Queensland|Western Australia|Northern Territory";
$cdnterrprov = "Ontario|Quebec|Nova Scotia|New Brunswick|Manitoba|British Columbia|Prince Edward Island|Saskatchewan|Alberta|Newfoundland and Labrador|Northwest Territories|Yukon|Nunavut";
$country = "Democratic Republic of the Congo";

$start = time();

if( $lang eq "commons" )
{
  $query = "SELECT /* SLOW_OK */ page_title, gc_lat, gc_lon, gc_head, img_width, img_height from page, image, u_dispenser_p.coord_commonswiki img_name = page_title and page_namespace=6 and gc_from = page_id and ( gc_globe ='' or gc_globe = 'earth')"; 
}
else
{
  $query = "SELECT /* SLOW_OK */ page_title, gc_lat, gc_lon, gc_head, page_len, gc_type, gc_size, gc_name  from page, image, u_dispenser_p.coord_commonswiki img_name = page_title and page_namespace=0 and gc_from = page_id and ( gc_globe ='' or gc_globe = 'earth')"; 
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
  ( $title, $lat, $lon, $head, $psize, $type, $pop, $name ) = @row[0..7];
  $url = $title;
  $title =~ s/_/ /g;

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

