#! /usr/bin/perl -w

use strict;
use Getopt::Long;
use Encode;
use lib '.'; #for password file.
use lib '../perl';
use FrameworkAPI;
use open ':utf8';
use feature ('switch', 'say');

#my $page = 'User:Sanbeg/stuff_to_archive';
my $page = 'User:Sanbeg_(bot)/archive_list';
my $do_edit;

GetOptions(edit=>\$do_edit);

my $wiki = FrameworkAPI->new('en.wikisource.org');
my $page_object = $wiki->get_page($page);
my $buf = $page_object->get_text;

for (split "\n", $buf) {
    #/^\G( .+)$/cogm and do {print "$_\n"};
    #/^\Q| [[\E(.+?)\]\]\s*\|\|\s*(.+)/ and do {
    if(/^\Q| [[\E(.+?)\]\]\s*\|\|\s*(.*)/) {
	say qq(-page "$1" $2);
	system qq(./archive.pl -page "$1" $2 -v -e) if $do_edit;
    }
    #/^\G(.+)$/cogm and redo;
}
