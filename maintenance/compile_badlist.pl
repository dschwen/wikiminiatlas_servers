#!/usr/bin/perl

 #######################################################################
 #
 # Article badlist compiler (c) 2009-2010 by Daniel Schwen
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

#$dsn = "dbi:mysql:enwiki_p:sql-s1:3306";
$dsn = "dbi:mysql:".$lang."wiki_p:".$server.":3306";
$db = DBI->connect( $dsn, $login_ds, $pass_ds,
                  { PrintError => 0}) || die $DBI::errstr;

$geohackurl = 'http://toolserver.org/~geohack/geohack.php?';

$query = "select /* SLOW_OK */ page_title, COUNT(*) as coords from externallinks, page where page_namespace = 0 and el_from = page_id and el_to like '".$geohackurl."%' and not el_to like '%&title=%' group by page_title having coords > 5 order by coords desc";

print STDERR "Starting query.\n";
$sth = $db->prepare( $query );
$sth->execute;
print STDERR "Query done.\n";

while( @row = $sth->fetchrow() ) 
{
    ( $title, $count ) = @row[0..1];
    print $count . "|" . $title . "\n"; 
}

$db->disconnect;

