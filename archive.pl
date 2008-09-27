#! /usr/bin/perl -w

use strict;
use Getopt::Long;
use Encode;
#use Perlwikipedia;

use lib '.'; #for password file.
use lib '../perl';
use FrameWorkPW;
use FrameworkAPI;
use passwd;

#use open ':raw';
#use open ':std';
use open ':utf8';

my $debug;
my $cfn;
my $ofn;
my $do_list;
my $do_edit;
my $add_month;
my $cut_date;
my $p='';
my $page = 'Wikisource:Scriptorium';

GetOptions('debug'=>\$debug, 'open=s'=>\$ofn, 'close=s'=>\$cfn, 
	   'list'=>\$do_list, 'edit!'=>\$do_edit,
	   'prefix=s'=>\$p, 'add!'=>\$add_month,
	   'cut=i'=>\$cut_date,);

# my $wiki = Perlwikipedia->new('Perl');
# $wiki->set_wiki('en.wikisource.org', 'w');
# my $l = $wiki->login($username, $password);
# print "status = $l, err=$wiki->{errstr}\n";
# die "login failed? - $wiki->{errstr}" unless $wiki->{errstr} eq '';

#my $wiki = FrameWorkPW->new('en.wikisource.org');
my $wiki = FrameworkAPI->new('en.wikisource.org');
$wiki->login('Sanbeg (bot)', 'lst');
$wiki->{write_prefix} = $p;

unless (defined $cut_date) {
    my @now = localtime;
    my $m = $now[4];
    my $y = $now[5] + 1900;

    for (1) {
	if ($m>=1) {
	    --$m;
	} else {
	    --$y;
	    $m=11;
	}
    }
    $cut_date = $m+$y*100;
}

my $cut_y = int($cut_date/100);
my $cut_m = $cut_date % 100;

print "$cut_m/$cut_y\n";
++$cut_m;
++$cut_m if $add_month;

my $anchor=sprintf "/$cut_y-%.2d", $cut_m;
my @months=qw(January February March April May June July August September October November December);

my %months;
for my $i (0..11) {
    $months{$months[$i]} = $i;
};

my $month_string = join '|', @months;
my $month_re = qr/$month_string/;

my $tlevel=7;
my $tline;
my $tdate;

my @close;
my $list_sep;
my $thead;

my $archive_summary = "*[[$anchor|$months[$cut_m-1]]]<small>";

sub f() {
    if ($tlevel <= 6) {
	print "$tlevel . $tline : $months[$tdate%100] ",$tdate/100,"\n" if $debug;
	if ($tdate <= $cut_date) {
	    push @close, [$tline, $. -1];
	    $archive_summary .= "$list_sep $thead";
	    $list_sep = '|';
	    return 1;
	}
    }
    return undef;
}

#my $buf = $wiki->get_text($page);
my $pg = $wiki->get_page($page);
my $buf = $pg->get_text;
die "$page: missing" unless defined $buf;

open FH, '<', \$buf or die "couldn't open handle: $!";
#binmode (FH);

while (<FH>) {
    /^(\=+)(.+?)\1$/ and do {
	my $level = length($1);
	if ($level > 1) {
	    if ($level <= $tlevel) {
		f();
		$tlevel = $level;
		$tline = $.;
		$tdate = -1;
		$thead = $2;
	    }
	print length($1), ": $2\n" if $debug;
	} else {
	    f();
	    $tlevel = 7;
	    $archive_summary .=  "\n**[[$anchor#$2|$2]]";
	    $list_sep = ':';
	};



    };
    m/[0-9][0-9]:[0-9][0-9], [0-9]{1,2} (${month_re}) ([0-9]{4}) \(UTC\)/ and do  {
	#print "$1 $2\n" if $debug;
	my $nd = $2*100+$months{$1};
	$tdate = $nd if $nd > $tdate;
    }
};

my @close2 = @close;
die "nothing to archive" unless @close;

my $edit_summary =  "[bot] automated archival of ".@close." sections older than 1 month\n";

print "\n$edit_summary\n$archive_summary\n";


my ($buf_open, $buf_close) = ('','');

############################################################
#print closed entries;
#open CFH, ">", \$buf_close or die "open failed: $!";
#binmode(CFH);
seek FH, 0,0;
$. = 0;
while (<FH>) {
    /^(\=+)(.+?)\1$/ and do {
	my $level = length($1);
	#print CFH if $level == 1;
	$buf_close .= $_ if $level == 1;
    };
    
    #print CFH  if ($. >= $close[0][0] and $. <= $close[0][1]);
    $buf_close .= $_  if ($. >= $close[0][0] and $. <= $close[0][1]);
    shift @close if $. == $close[0][1];
    last unless @close;
};
#close CFH;

############################################################

#print open entries;
#open OFH, ">", \$buf_open or die "open failed: $!";
#binmode(OFH);
seek FH, 0,0;
$. = 0;

while (<FH>) {
    last unless @close2;
    #print OFH if ($. < $close2[0][0]);
    $buf_open .= $_ if ($. < $close2[0][0]);
    shift @close2 if $. == $close2[0][1];
}
#print OFH while <FH>;
$buf_open .= $_ while <FH>;
#close OFH;

############################################################
close FH;

############################## test ##############################
if (defined $ofn) {
    open TFH, ">$ofn" or die;
    #binmode TFH;
    print TFH $buf_open;
    close TFH;
}
if (defined $cfn) {
    open TFH, ">$cfn" or die;
    print TFH $buf_close;
    close TFH;
}


############################## the real thing ##############################

my $archive_page = "$page/Archives";
my $subpage = $archive_page . $anchor;
print "$subpage\n";

if ($do_edit) {

    my $archive_page = "$page/Archives";
    my $subpage = $archive_page . $anchor;

#     $wiki->edit($p.$subpage, ($buf_close), $edit_summary, undef, '&assert=bot');
#     my $text = $wiki->get_text($archive_page) . $archive_summary . '</small>';
#     $wiki->edit($p.$archive_page,$text, $edit_summary, undef, '&assert=bot');
#     $wiki->edit($p.$page, ($buf_open), $edit_summary, undef, '&assert=bot');

    my $archive_pg = $wiki->get_page ($archive_page);
    my $sub_pg = $wiki->create_page ($subpage);

    $sub_pg->edit($buf_close, $edit_summary);
    
    my $text = $archive_pg->get_text . $archive_summary . '</small>';
    $archive_pg->edit($text,$edit_summary);
    $pg->edit($buf_open, $edit_summary);

}
