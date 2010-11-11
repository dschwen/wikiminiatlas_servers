#!/usr/bin/perl
use List::Util qw[min max];

my $v1;
my $v2;

$pw = 100;
$ph = 100;

print "<?xml version=\"1.0\" encoding=\"iso-8859-1\" standalone=\"no\"?>
  <!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.0//EN\"
    \"http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd\">
  <svg xmlns=\"http://www.w3.org/2000/svg\"
       xmlns:xlink=\"http://www.w3.org/1999/xlink\"
       width=\"$pw\" height=\"$ph\" viewBox=\"0 0 1 1\">
  <defs>
    <style type=\"text/css\">
      <![CDATA[
        path {fill: none; stroke-width:0.5; stroke-linecap: round }
      ]]>
    </style>
  </defs>
    ";

$pi = 3.14159265;

# angle of pointer
$ang = ( ( $ARGV[0] * $pi ) / 180.0 );
$da = $pi - 0.3;

#opacity
$o = 0.75;

$s = 0.075;
$r1 = 0.5 - $s/2.0;
$r2 = 0.5 - $s;

#tip of pointer
$x1 = cos($ang) * $r2 + 0.5;
$y1 = 0.5 - sin($ang) * $r2;

#two corners of the blunt end
$x2 = cos($ang+$da) * $r2 + 0.5;
$y2 = 0.5 - sin($ang+$da) * $r2;
$x3 = cos($ang-$da) * $r2 + 0.5;
$y3 = 0.5 - sin($ang-$da) * $r2;

# roundel
print "<circle cx=\"0.5\" cy=\"0.5\" r=\"$r1\" style=\"stroke: black; stroke-width:$s; fill: none\" opacity=\"$o\"/>\n";
print "<circle cx=\"0.5\" cy=\"0.5\" r=\"$r2\" style=\"stroke: none; fill: white\" opacity=\"$o\"/>\n";

#pointer
print "<path d=\"M $x1 $y1 L $x2 $y2 L $x3 $y3 Z\" style=\"stroke: none; fill: black\"/>\n";

print "</svg>";

#<image x="20" y="20" width="300" height="80"
#     xlink:href="http://jenkov.com/images/layout/top-bar-logo.png" />
