#! /usr/bin/perl -w

use strict;
use Getopt::Long;
use Encode;
use lib '.'; #for password file.
use lib '../perl';
use FrameworkAPI;
use passwd;
use open ':utf8';

my $debug;
my $cfn;
my $ofn;
my $do_list;
my $do_edit;
my $cut_date;
my $archive_date;
my $n_days = 30;
my $p='';
my $page = 'Wikisource:Scriptorium';
my $be_anon;
my $force;
my $header_level = 1;

sub relocate_links {
    my @strip_state;
    for (@_) {
	my $strip_text=sub( $ ) {
	    push (@strip_state, $_[0]);
	
	    return "<$#strip_state>";
	};

	next unless m{\Q[[/};

	s{(<(nowiki|pre)\s*>(.*?)</\2\s*>|<[0-9]+>)}{$strip_text->($1)}ge;
	s{\Q[[/}{[[$page/}g;

	s{<([0-9]+)>}{$strip_state[$1]}ge;
	@strip_state = ();
    }
}

GetOptions('page=s'=>\$page,
	   'debug'=>\$debug, 'open=s'=>\$ofn, 'close=s'=>\$cfn, 
	   'list'=>\$do_list, 'edit!'=>\$do_edit, 'anon!'=>\$be_anon,
	   'prefix=s'=>\$p, 'day=i'=>\$n_days,
	   'cut=i'=>\$cut_date,'force!'=>\$force,'head=i'=>\$header_level);

my $wiki = FrameworkAPI->new('en.wikisource.org');
$be_anon = 1 unless $do_edit;
$wiki->login($::username, $::password) unless $be_anon;

$wiki->{write_prefix} = $p;

##############################
# Calculate dates
##############################
unless (defined $archive_date) {
    my @now = localtime;
    my $m = $now[4];
    my $y = $now[5] + 1900;

    $archive_date = $m+$y*100;
}

my $archive_year = int($archive_date/100);
my $archive_month = $archive_date % 100 + 1;

print "$archive_month/$archive_year\n";
my $anchor=sprintf "/$archive_year-%.2d", $archive_month;

#$cut_date *= 100;
unless (defined $cut_date) {
    my @now = localtime(time-60*60*24*$n_days);
    my $d = $now[3];
    my $m = $now[4];
    my $y = $now[5] + 1900;
    $cut_date = $d+$m*100+$y*10000;
}
##############################  


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

my $archive_summary = "*[[$anchor|$months[$archive_month-1]]]<small>";

sub f() {
    if ($tlevel <= 6) {
	if ($debug){
	    my $month = $months[int($tdate/100)%100];
	    my $day = $tdate % 100;
	    my $year = int($tdate / 10000);
	    print "$tlevel . $tline : $month $day $year\n";
	}
	if ($tdate <= $cut_date) {
	    push @close, [$tline, $. -1];
	    #$archive_summary .= "$list_sep $thead";
	    $list_sep = '|';
	    return 1;
	}
    }
    return undef;
}

##############################
# Access project page
##############################

#my $buf = $wiki->get_text($page);
my $pg = $wiki->get_page($page);
my $buf = $pg->get_text;
die "$page: missing" unless defined $buf;

open PAGE_FH, '<', \$buf or die "couldn't open handle: $!";
#binmode (PAGE_FH);

##scan for closed sections
while (<PAGE_FH>) {
    /^(\=+)(.+?)\1$/ and do {
	my $level = length($1);
	if ($level > $header_level) {
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
    m/[0-9][0-9]:[0-9][0-9], ([0-9]{1,2}) (${month_re}) ([0-9]{4}) \(UTC\)/ and do  {
	#print "$1 $2\n" if $debug;
	my $nd = $3*10000+$months{$2}*100+$1;
	$tdate = $nd if $nd > $tdate;
    }
};

my @close2 = @close;
die "nothing to archive" unless $force or @close;

my $edit_summary =  "[bot] automated archival of ".@close." sections older than $n_days days";

print "\n$edit_summary\n$archive_summary\n";


my ($buf_open) = ('');


##############################
#print open entries for discussion page
##############################
seek PAGE_FH, 0,0;
$. = 0;

while (<PAGE_FH>) {
    $buf_open .= $_, last unless @close2;
    #FIXME CHECK - lost 1 line before, was $. < $close2...
    $buf_open .= $_ if ($. < $close2[0][0]); 
    shift @close2 if $. == $close2[0][1];
}
$buf_open .= $_ while <PAGE_FH>;
#close PAGE_FH;
##############################

##############################


##############################
#print closed entries for archive page
##############################

my $archive_page = "$page/Archives";
my $subpage = $archive_page . $anchor;
print "$subpage\n";

seek PAGE_FH, 0,0;
$. = 0;

my $sub_pg = $wiki->get_page ($subpage);

my %merge_text;
my $have_merge_text;
my @majors;

##slurp existing entries from subpage
if ($sub_pg->exists) {
    warn "$subpage exists, merging";
    $have_merge_text=1;
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

##copy closed threads, merging in subpage.
my $buf_close = exists($merge_text{''}) ?
    delete $merge_text{''} : "{{archive header}}\n";

while (<PAGE_FH>) {
    last unless @close;
    /^(\=+)\s*(.+?)\s*\1$/ and do {
	my $level = length($1);
	#print CFH if $level == 1;
	if ($level <= $header_level) {
	    if (defined $merge_text{$2}) {
		$buf_close .= delete $merge_text{$2};
		#delete $merge_text{$2};
	    } else {
		warn "no heading: $2" if ($have_merge_text);
		$buf_close .= $_;
	    }
	}
    };
    
    #print CFH  if ($. >= $close[0][0] and $. <= $close[0][1]);
    $buf_close .= $_  if ($. >= $close[0][0] and $. <= $close[0][1]);
    shift @close if $. == $close[0][1];
};

close PAGE_FH;

foreach my $heading (@majors) {
    $buf_close .= delete $merge_text{$heading} 
    if (defined $merge_text{$heading});
};
foreach my $c (keys %merge_text) {
    warn "unused heading: $c";
};


relocate_links $buf_close;

##############################
#rescan summary from closed page, since some won't be ours.
##############################

{
    open my($fh), '<', \$buf_close or die "couldn't open handle: $!";

    my $thead='';
    my $fs;
    $tlevel = 7;

    while (<$fh>) {
	/^(\=+)(.+?)\1$/ and do {
	    my $level = length($1);
	    if ($level <= $header_level) {
		$fs = "\n**[[$anchor#$2|$2]]:";
		$tlevel = 7;
	    } elsif ($level <= $tlevel) {
		$archive_summary .= $fs . $2;
		$fs = '|';
		$tlevel = $level;
	    }
	};
    }
    close $fh;
    $archive_summary .= "</small>\n";
    print "new sum is:\n $archive_summary\n" if $debug;
}

#open was here...

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

    $sub_pg->edit($buf_close, $edit_summary . " from [[$page]]");
    
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


    $pg->edit($buf_open, $edit_summary . " to [[$page/Archives$anchor]]");

}

