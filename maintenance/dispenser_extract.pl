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

print "Connected.\n";

#$blacklist['en'] = "List of |History of |Geography of |Latitude and longitude of cities|Former toponyms of places in |Second Happy Time|Finnish exonyms for places in |Abbeys and priories in England|Wide Area Augmentation System|Australian places named by ";

$usstates = "Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|Florida|Georgia|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming";
$auterritories = "New South Wales|Victoria|South Australia|Queensland|Western Australia|Northern Territory";
$cdnterrprov = "Ontario|Quebec|Nova Scotia|New Brunswick|Manitoba|British Columbia|Prince Edward Island|Saskatchewan|Alberta|Newfoundland and Labrador|Northwest Territories|Yukon|Nunavut";
$country = "Democratic Republic of the Congo";

$start = time();

$query = "SELECT /* SLOW_OK */ page_title, gc_lat, gc_lon, gc_head, page_len, gc_type, gc_size, gc_name FROM page, u_dispenser_p.coord_".$lang."wiki WHERE page_namespace=0 AND gc_from = page_id AND ( gc_globe ='' or gc_globe = 'earth')"; 

@bl = split( /\|/, $blacklist[$lang] );

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
  $pop = int($pop);
  $title =~ s/_/ /g;

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

  # explicit title given?
  if( $name ne $title ) 
  { 
    $title2 = $name; 
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

