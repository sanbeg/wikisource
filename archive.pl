#! /usr/bin/perl -w

use strict;
use Getopt::Long;
use Encode;
use lib '.'; #for password file.

use lib '../MediaWiki-EditFramework/lib';
use MediaWiki::EditFramework;
use Date;
use Link;
use PageDate;
use passwd;
use open ':utf8';

my $debug;
my $verbose;
my $cfn;
my $ofn;
my $do_list;
my $do_edit;
my $cut_date;
my $n_days = 30;
my $p='';
my $page = 'Wikisource:Scriptorium';
my $be_anon;
my $force;
my $header_level = 1;
my $annual;
my $skew=0;
my $do_edit_archive = 1;
my $do_edit_index = 1;


GetOptions('page=s'=>\$page, 'annual=i'=>\$annual,
	   'debug'=>\$debug, 'open=s'=>\$ofn, 'close=s'=>\$cfn, 
	   'list'=>\$do_list, 'edit!'=>\$do_edit, 'anon!'=>\$be_anon,
	   'prefix=s'=>\$p, 'day=i'=>\$n_days, 'skew=i'=>\$skew,
	   'cut=i'=>\$cut_date,'force!'=>\$force,'head=i'=>\$header_level,
	   'archive!'=>\$do_edit_archive, 'index!'=>\$do_edit_index,
	   'verbose'=>\$verbose);

my $wiki = MediaWiki::EditFramework->new('en.wikisource.org');
$be_anon = 1 unless $do_edit;
$wiki->login($::username, $::password) unless $be_anon;

$wiki->{write_prefix} = $p;

##############################
# Calculate dates
##############################
my $archive_date = PageDate->new(annual=>$annual, date=>{months=>$skew});
print $archive_date->page, "\n";
my $anchor = $archive_date->anchor;
my $archive_summary = '*' . $archive_date->link . '<small>';

$cut_date=Date->new(date=>$cut_date, days=>$n_days);
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
my $thead;


sub f() {
    if ($tlevel <= 6) {
	if ($debug){
	    my $month = $tdate->month_name;
	    my $day = $tdate->day;
	    my $year = $tdate->year;
	    print "$tlevel . $tline : $month $day $year\n";
	}
	if ($tdate <= $cut_date) {
	    push @close, [$tline, $. -1];
	    #$archive_summary .= "$list_sep $thead";
	    return 1;
	}
    }
    return undef;
}

##############################
# Access project page
##############################

#my $buf = $wiki->get_text($page);
my $page_object = $wiki->get_page($page);
my $heading_re = qr/^(\=+)\s*(.+?)\s*\1$/;

if ($do_edit_archive) {
    my $buf = $page_object->get_text;
    die "$page: missing" unless defined $buf;
	
    open PAGE_FH, '<', \$buf or die "couldn't open handle: $!";
	#binmode (PAGE_FH);
	
	##scan for closed sections
    while (<PAGE_FH>) {
		/$heading_re/ and do {
			my $level = length($1);
			print length($1), ": $2\n" if $debug;
			if ($level > $header_level) {
				if ($level <= $tlevel) {
					f();
					$tlevel = $level;
					$tline = $.;
					$tdate = Date->new(date=>-1);
					$thead = $2;
				}
			} else {
				f();
				$tlevel = 7;
				#$archive_summary .=  "\n**[[$anchor#$2|$2]]";
			};
		};
		m/[0-9][0-9]:[0-9][0-9], ([0-9]{1,2}) (${month_re}) ([0-9]{4}) \(UTC\)/ 
		  and do  {
			  #print "$1 $2\n" if $debug;
			  my $nd=Date->new(date=>{y=>$3,m=>$months{$2},d=>$1});
			  $tdate = $nd if $nd > $tdate;
		  }
	};
};

my @close2 = @close;
$force = 1 unless $do_edit_archive;
die "nothing to archive" unless $force or @close;

my $edit_summary;

if ($do_edit_archive and @close) {
    $edit_summary =  "[bot] automated archival of ".
	@close.
	" sections older than $n_days days";
} else {
    $edit_summary = "[bot] rewrite archive index for " . $archive_date->page;
};

print "\n$edit_summary\n$archive_summary\n" if $verbose;


my ($buf_open) = ('');


##############################
#print open entries for discussion page
##############################
if ($do_edit_archive) {
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
};

##############################

##############################


##############################
#print closed entries for archive page
##############################

my $archive_index_page = "$page/Archives";
my $subpage = $archive_index_page . $anchor;
print "$subpage\n";

if ($do_edit_archive) {
    seek PAGE_FH, 0,0;
    $. = 0;
}

my $archive_subpage_object = $wiki->get_page ($subpage);

my %merge_text;
my $have_merge_text;
my @majors;

##slurp existing entries from subpage
if ($archive_subpage_object->exists) {
    warn "$subpage exists, merging";
    $have_merge_text=1;
    my $buf = $archive_subpage_object->get_text;
    die "$page: missing" unless defined $buf;
    
    open my($fh), '<', \$buf or die "couldn't open handle: $!";

    my $major = '';

    while (<$fh>) {
	/$heading_re/ and do {
	    my $level = length($1);
	    if ($level == 1) {
		$major = $2;
		push @majors, $major;
	    }
	};
	$merge_text{$major} .= $_;
    }
    close $fh;
} elsif (not @close) {
    die "No closed threads to index";
}

##copy closed threads, merging in subpage.
my $buf_close = exists($merge_text{''}) ?
    delete $merge_text{''} : "{{archive header}}\n";

if ($do_edit_archive) {
    while (<PAGE_FH>) {
	last unless @close;
	/$heading_re/ and do {
	    my $level = length($1);
	    #print CFH if $level == 1;
	    if ($level <= $header_level) {
		if (defined $merge_text{$2}) {
		    $buf_close .= delete $merge_text{$2};
		    $buf_close .= "\n"; #was losig this somewhere.
		    #delete $merge_text{$2};
		} else {
		    warn "no heading: $2" if ($have_merge_text);
		    $buf_close .= "$_\n";
		}
	    }
	};
	
	#print CFH  if ($. >= $close[0][0] and $. <= $close[0][1]);
	$buf_close .= $_  if ($. >= $close[0][0] and $. <= $close[0][1]);
	shift @close if $. == $close[0][1];
    };
    
    close PAGE_FH;
}

foreach my $heading (@majors) {
    $buf_close .= delete $merge_text{$heading} 
    if (defined $merge_text{$heading});
};
foreach my $c (keys %merge_text) {
    warn "unused heading: $c";
};


Link::relocate ($page,$buf_close);

##############################
#rescan summary from closed page, since some won't be ours.
##############################
my @all_closed_sections;
{
    open my($fh), '<', \$buf_close or die "couldn't open handle: $!";

    my $thead='';
    my $fs=':';
    $tlevel = 7;

    while (<$fh>) {
	/$heading_re/ and do {
	    my $level = length($1);
	    if ($level <= $header_level) {
		$fs = "\n**[[$anchor#$2|$2]]:";
		$tlevel = 7;
	    } elsif ($level <= $tlevel) {
		$archive_summary .= $fs . $2;
		$fs = '|';
		$tlevel = $level;
		push @all_closed_sections, $2;
	    }
	};
    }
    close $fh;
    $archive_summary .= "</small>\n";
    print "new index is:\n $archive_summary\n" if $verbose;
}

Link::relocate_src($subpage,\@all_closed_sections,$buf_open);

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

    if ($do_edit_archive) {
	#edit the archive subpage wikisource/archives/date
	$archive_subpage_object->edit($buf_close, 
				      $edit_summary." from [[$page]]");
	#once text is copied, edit the discusion wikiwource:scriptorium
	$page_object->edit($buf_open, 
			   $edit_summary . " to [[$page/Archives$anchor]]");    
    };

    if ($do_edit_index) {
	my $archive_index_object = $wiki->get_page ($archive_index_page);

	my $text = '';
	my $temp_text = $archive_index_object->get_text;
	foreach my $line (split "\n", $temp_text) {
	    $text .= "$line\n" unless $line =~ /^\*+\s*\[\[$anchor/;
	}
	$text .= $archive_summary;
	#print "text is:\n $text";
	
	$archive_index_object->edit($text,$edit_summary);
    }
}
