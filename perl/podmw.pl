#! /usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../perl";
use PodMw;

my $parser = PodMw->new;
$parser->parse_from_filehandle(\*STDIN)  if (@ARGV == 0);
for (@ARGV) { $parser->parse_from_file($_); }
