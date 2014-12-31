#! /usr/bin/perl -w

use strict;
use Getopt::Long;
use Encode;
use lib '.'; #for password file.
use lib 'lib';
use lib '../MediaWiki-EditFramework/lib';
use MediaWiki::EditFramework;
use Date;
use Link;
use PageDate;
use ArchivePageText;
use passwd;
use open ':utf8';

my $debug;
my $verbose;
my $cfn;
my $ofn;
my $do_list;
my $do_edit;
my $do_bot = 1;
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
my $dump_dir;
my ($username, $password);

GetOptions('page=s'=>\$page, 'annual=i'=>\$annual,
	   'debug'=>\$debug, 'open=s'=>\$ofn, 'close=s'=>\$cfn, 
	   'list'=>\$do_list, 'edit!'=>\$do_edit, 'anon!'=>\$be_anon,
	   'prefix=s'=>\$p, 'day=i'=>\$n_days, 'skew=i'=>\$skew,
	   'cut=i'=>\$cut_date,'force!'=>\$force,'head=i'=>\$header_level,
	   'archive!'=>\$do_edit_archive, 'index!'=>\$do_edit_index,
	   'verbose'=>\$verbose, 'dump=s'=>\$dump_dir,
	   'bot!' => \$do_bot,
	   'username=s'=>\$username, 'password=s'=>\$password);

$username //= $::username;
$password //= $::password;

my $wiki = MediaWiki::EditFramework->new('en.wikisource.org');
$be_anon = 1 unless $do_edit;
$wiki->login($username, $password) unless $be_anon;

$wiki->{write_prefix} = $p;
$wiki->{text_dump_dir} = $dump_dir;

##############################
# Calculate dates
##############################
my $archive_date = PageDate->new(annual=>$annual, date=>{months=>$skew});
print $archive_date->page, "\n";
my $anchor = $archive_date->anchor;
my $archive_summary = '*' . $archive_date->link . '<small>';

$cut_date=Date->new(date=>$cut_date, days=>$n_days);
##############################  

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
my $page_fh;

sub find_closed_sections {
  ##scan for closed sections
    while (<$page_fh>) {
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
		m/[0-9][0-9]:[0-9][0-9], ([0-9]{1,2}) (${Date::month_re}) ([0-9]{4}) \(UTC\)/ 
		  and do  {
			  #print "$1 $2\n" if $debug;
			  my $nd=Date->new(date=>{y=>$3,month=>$2,d=>$1});
			  $tdate = $nd if $nd > $tdate;
		  }
	};

}

if ($do_edit_archive) {
    my $buf = $page_object->get_text;
    die "$page: missing" unless defined $buf;
    open $page_fh, '<', \$buf or die "couldn't open handle: $!";
	#binmode ($page_fh);
    find_closed_sections;
};

$force = 1 unless $do_edit_archive;
die "nothing to archive" unless $force or @close;

my $edit_summary;

if ($do_edit_archive and @close) {
  my $bot_label = $do_bot ? '[bot] automated ' : '';
  $edit_summary =
    $bot_label     .
    "archival of " .
    @close         .
    " sections older than $n_days days";
} else {
  my $bot_label = $do_bot ? '[bot] ' : '';
  $edit_summary = "${bot_label}rewrite archive index for "
    . $archive_date->page;
};

print "\n$edit_summary\n$archive_summary\n" if $verbose;

##############################
#print open entries for discussion page
##############################

sub extract_open_sections {
  my $page_fh = shift;
  my $closed = shift;
  my $buf_open = '';

  my @close2 = @$closed;
  seek $page_fh, 0,0;
  $. = 0;
  
  while (<$page_fh>) {
    $buf_open .= $_, last unless @close2;
    #FIXME CHECK - lost 1 line before, was $. < $close2...
    $buf_open .= $_ if ($. < $close2[0][0]); 
    shift @close2 if $. == $close2[0][1];
  }
  $buf_open .= $_ while <$page_fh>;
  return $buf_open;
}

my $buf_open = $do_edit_archive ? extract_open_sections( $page_fh, \@close ) : '';

##############################
#print closed entries for archive page
##############################

my $archive_index_page = "$page/Archives";
my $subpage = $archive_index_page . $anchor;
print "$subpage\n";

if ($do_edit_archive) {
    seek $page_fh, 0,0;
    $. = 0;
}

my $archive_subpage_object = $wiki->get_page ($subpage);
my $archive_page_content;

##slurp existing entries from subpage
if ($archive_subpage_object->exists) {
    warn "$subpage exists, merging";
    $archive_page_content = ArchivePageText->new($archive_subpage_object->get_text);
} elsif (@close) {
    $archive_page_content = ArchivePageText->new("{{archive header}}\n");
} else {
    die "No closed threads to index";
}

##copy closed threads, merging in subpage.
if ($do_edit_archive) {
    $archive_page_content->merge($page_fh, \@close, $header_level);
}

my $buf_close = $archive_page_content->text;
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
