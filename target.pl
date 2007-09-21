#! /usr/bin/perl -w

use strict;
use Getopt::Long;

my $grab;
my $prev=0;
my $prev_ch = 0;
my $verses;
my $cat = '[[Category:Labeled section transclusion targets]]';
my $have_cat;

my $do_replace;
GetOptions('log=s' => \$verses, 'replace!'=>\$do_replace);

my $whole_article  = join('',<>);
#don't add cat if it's already there.  Maybe just skip the whole thing?
$have_cat = 1 if $whole_article =~ $cat; 

my @verses;

#try to guess how we're marked up
if ($whole_article =~ /\{\{verse/) { 

    my $open_section ;
#new markup
    for ($whole_article) {
	s/<section [^>]+>//g  if ($do_replace);
	#close sections before headings
	$open_section and /^\G(\=|\{\{[Bb]iblecontents)/cogm and do {
	    print "<section end=$prev_ch:$prev/>\n$1";
	    $open_section = undef;
	};
	##case 1 - no markup, leading int.
	#doesn't seem to get whitespace right, hence the if/else above to
	#avoid this.
	0 and /^\G([0-9]+)\s+(.+)$/cogm and do {
	    my $cur = $1;
	    my $text = $2;
	    unless (++$prev == $cur) {
		die "section mismatch $prev != $cur";
	    };
	    next if $text =~ /^<section/;
	    chomp $text;
	    #have to know if | is in {{}} to know how to deal, but that
	    #shouldn't happen often
	    die "Found | in section" if $text =~ /a/;
	    print "$cur <section begin=1:$prev/>$text<section end=1:$prev/>\n";
	    push @verses, "1 $cur";
	};
	##case two, look for {{verse}}
	/\G(\s*{{verse\|chapter=([0-9]+)\|verse=([0-9]+)}}\s*)/cog and do{
	    my $cur_ch = $2;
	    my $cur = $3;
# 	    unless ((++$prev == $cur and $prev_ch == $cur_ch)
# 		    or ($cur == 1 and ++$prev_ch == $cur_ch)) {
# 		die "section mismatch $prev_ch/$prev != $cur_ch/$cur: $1";
# 	    };

	    if (($prev+1 == $cur and $prev_ch == $cur_ch) ||
		($cur == 1 and $prev_ch+1 == $cur_ch)) {
		if ($open_section) {
		    print "<section end=$prev_ch:$prev/>";
		    $open_section = undef;
		}
		$prev=$cur;
		$prev_ch=$cur_ch;
	    } else {
		die "section mismatch $prev_ch/$prev != $cur_ch/$cur: $1";
	    };

	    #warn "got sec $prev: $1\n";
	    $grab=1;
	    print $1;
	    #push @verses, "$cur_ch $cur";
	    redo;
	};
	$grab and /\G([^\{0-9\=\n]+)/cogs and do {
	    my $text = $1;
	    unless ($text =~ /^\{\{\{\#(?:section|lst)/){
		#my $nl = chomp($text)?"\n":"";
		my $nl ='';
		if ($text =~ s/(\s+)$//) {
		    $nl = $1;
		};
		#die "Found | in section" if $text =~ /\|/;		
		#print "<section begin=${prev_ch}:$prev/>$text<section end=${prev_ch}:$prev/>$nl";
		print "<section begin=${prev_ch}:$prev/>$text$nl";
		$open_section = 1;
		push @verses, "$prev_ch $prev";
	    } else {
		print $text;
	    };
	    undef $grab;
	    redo;
	};
	/\G([^\{\n]+)/cog||/\G(.|\n)/cog and do {
	    print $1;
	    redo;
	};
    }
} else {
    
    my $chapter=1;
    for (split "(\n)", $whole_article) {

	/^==Chapter ([0-9]+)==$/ and do {
	    unless ($1 == 1 or ++$chapter == $1) {
		die "chapter mismatch $chapter != $1";
	    };
	    $prev=0;
	};
	
	/^([0-9]+|[0-9]+:[0-9]+)\s*(.+)/ and do {
	    my $cur = $1;
	    my $text = $2;
	    my $ch = $chapter;
	    if ($cur =~ /:/) {
		($ch,$cur) = split ':', $cur;
	    }
	    unless (++$prev == $cur) {
		die "section mismatch $prev != $cur (chapter $chapter)";
	    };
	    unless ($text =~ /^<section/) {
		#chomp $text; #rm nl in split.
		$text =~ s/\|/{{!}}/g;
		if (defined $chapter) {
		    $_ = "{{verse|chapter=$ch|verse=$cur}} <section begin=${ch}:$prev/>$text<section end=${ch}:$prev/>";
		    push @verses, "$ch $prev";
		} else {
		    $_ = "$cur <section begin=1:$prev/>$text<section end=1:$prev/>";
		}
	    }
	};
	
    } continue {
	print;
    }
};


if (defined $verses) {
    open FH, ">$verses";
    print FH "$_\n" for @verses;
    close FH;
};
