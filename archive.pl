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
my $add_month=1;
my $cut_date;
my $p='';
my $page = 'Wikisource:Scriptorium';
my $be_anon;
my $force;

GetOptions('debug'=>\$debug, 'open=s'=>\$ofn, 'close=s'=>\$cfn, 
	   'list'=>\$do_list, 'edit!'=>\$do_edit, 'anon!'=>\$be_anon,
	   'prefix=s'=>\$p, 'add!'=>\$add_month,
	   'cut=i'=>\$cut_date,'force!'=>\$force);

#my $wiki = FrameWorkPW->new('en.wikisource.org');
my $wiki = FrameworkAPI->new('en.wikisource.org');
$be_anon = 1 unless $do_edit;
$wiki->login($::username, $::password) unless $be_anon;
$wiki->_groups;

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
	    #$archive_summary .= "$list_sep $thead";
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
	    #$archive_summary .=  "\n**[[$anchor#$2|$2]]";
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
die "nothing to archive" unless $force or @close;

my $edit_summary =  "[bot] automated archival of ".@close." sections older than 1 month\n";

print "\n$edit_summary\n$archive_summary\n";


my ($buf_open, $buf_close) = ('','');

############################################################
my $archive_page = "$page/Archives";
my $subpage = $archive_page . $anchor;
print "$subpage\n";


############################################################
#print closed entries;
#open CFH, ">", \$buf_close or die "open failed: $!";
#binmode(CFH);
seek FH, 0,0;
$. = 0;

my $sub_pg = $wiki->get_page ($subpage);

my %merge_text;
my @majors;

if ($sub_pg->exists) {
    warn "$subpage exists, merging";

    my $buf = $sub_pg->get_text;
    die "$page: missing" unless defined $buf;
    
    open my($fh), '<', \$buf or die "couldn't open handle: $!";

    my $major = '';

    while (<$fh>) {
	/^(\=+)\s*(.+?)\s*\1$/ and do {
	    my $level = length($1);
	    if ($level == 1) {
		$major = $2;
		push @majors, $major;
	    }
	};
	$merge_text{$major} .= $_;
    }
    close $fh;
}



while (<FH>) {
    last unless @close;
    /^(\=+)\s*(.+?)\s*\1$/ and do {
	my $level = length($1);
	#print CFH if $level == 1;
	if ($level == 1) {
	    if (defined $merge_text{$2}) {
		$buf_close .= delete $merge_text{$2};
		#delete $merge_text{$2};
	    } else {
		warn "no heading: $2";
		$buf_close .= $_;
	    }
	}
    };
    
    #print CFH  if ($. >= $close[0][0] and $. <= $close[0][1]);
    $buf_close .= $_  if ($. >= $close[0][0] and $. <= $close[0][1]);
    shift @close if $. == $close[0][1];
};
#close CFH;

foreach my $heading (@majors) {
    $buf_close .= delete $merge_text{$heading} 
    if (defined $merge_text{$heading});
};
foreach my $c (keys %merge_text) {
    warn "unused heading: $c";
};

#rescan summary from closed page, since some won't be ours.

{
    open my($fh), '<', \$buf_close or die "couldn't open handle: $!";

    my $thead='';
    my $fs;
    while (<$fh>) {
	/^(\=+)(.+?)\1$/ and do {
	    my $level = length($1);
	    if ($level == 1) {
		$fs = "\n**[[$anchor#$2|$2]]:";
	    } elsif ($level == 2) {
		$archive_summary .= $fs . $2;
		$fs = '|';
	    }
	};
    }
    close $fh;
    $archive_summary .= "</small>\n";
    #print "new sum is $archive_summary";
}


############################################################

#print open entries;
#open OFH, ">", \$buf_open or die "open failed: $!";
#binmode(OFH);
seek FH, 0,0;
$. = 0;

while (<FH>) {
    $buf_open .= $_, last unless @close2;
    #print OFH if ($. < $close2[0][0]);
#FIXME CHECK - lost 1 line before, was $. < $close2...
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

if ($do_edit) {

    warn "doing edit";

    my $archive_pg = $wiki->get_page ($archive_page);

    $sub_pg->edit($buf_close, $edit_summary);
    
    #my $text = $archive_pg->get_text . $archive_summary;
    #kill links to our page, so we can regen..

    my $text = '';
    my $temp_text = $archive_pg->get_text;
    foreach my $line (split "\n", $temp_text) {
	$text .= "$line\n" unless $line =~ /^\*+\[\[$anchor/;
    }
    $text .= $archive_summary;
    #print "text is:\n $text";

    $archive_pg->edit($text,$edit_summary);
    $pg->edit($buf_open, $edit_summary);

};

