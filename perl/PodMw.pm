use Pod::Parser;
use strict;
package PodMw;
our @ISA = qw(Pod::Parser);

my $list_depth; #should keep track of stacks

sub command {
    my ($parser, $command, $paragraph, $line_num) = @_;
    my $out_fh = $parser->output_handle();
    
    chomp $paragraph; chomp $paragraph;
    my $expansion = $parser->interpolate($paragraph, $line_num);

    if ($command =~ /^head([1-4])/) {
	my $level = $1+1;
	print $out_fh '='x$level, $expansion, '='x$level, "\n";
    } elsif ($command eq 'item') {
	if ($paragraph eq '*') {
	    print $out_fh "*";
	} else {
	    $expansion =~ s/:/&\#58;/go;
	    print $out_fh ";$expansion:\n";
	}
    } elsif ($command eq 'over') {
	$parser->{list_depth}++;
    } elsif ($command eq 'back') {
	$parser->{list_depth}--;
    } elsif ($command eq 'for') {
	#can pass through html
	my ($form, $text) = split " ", $paragraph, 2;
	print $out_fh $text, "\n" if $form eq 'html' or $form eq 'mediawiki';
    } elsif ($command eq 'begin' or $command eq 'end' or $command eq 'pod') {
	
    } else {
	warn "command is $command";
    }
};

sub verbatim {
    my ($parser, $paragraph, $line_num) = @_;
    ## Format verbatim paragraph; make sure it uses leading spaces,
    #tabs aren't verbatem in wiki
    my $out_fh = $parser->output_handle();
    chomp $paragraph; chomp $paragraph;

    $paragraph =~ s/\t/        /go;
    print $out_fh $paragraph, "\n \n";
}

sub textblock {
    my ($parser, $paragraph, $line_num) = @_;
    ## Translate/Format this block of text; just add extra newline to seperate
    my $out_fh = $parser->output_handle();
    my $expansion = $parser->interpolate($paragraph, $line_num);
    print $out_fh $expansion, "\n";
}


sub interior_sequence {
    my ($parser, $seq_command, $seq_argument) = @_;
    ## Expand an interior sequence; sample actions might be:
    return "'''$seq_argument'''"     if ($seq_command eq 'B');
    return "<tt>$seq_argument</tt>"     if ($seq_command eq 'C');
    return "''${seq_argument}''"  if ($seq_command eq 'I');
    return "''${seq_argument}''"  if ($seq_command eq 'F');
    return '' if $seq_argument eq 'X' or $seq_argument eq 'Z';
    #FIXME - need to handle non-printing (i.e. URL)
    if ($seq_command eq 'S'){
	$seq_argument =~ s/\s/&nbsp;/g;
	return $seq_argument;
    };

    if ($seq_command eq 'E') {
	$seq_argument = '124;' if $seq_argument eq 'verbar';
	$seq_argument = '47;' if $seq_argument eq 'sol';

	if ($seq_argument =~ /^0x[[:xdigit:]]+$/) {
	    return '&#'.hex($seq_argument).';';
	} elsif ($seq_argument =~ /^0[0-7]+$/) {
	    return '&#'.oct($seq_argument).';';
	} elsif ($seq_argument =~ /^[[:digit:]]$/) {
	    return "&#$seq_argument;";
	} else {
	    return "&$seq_argument;";
	}
    }

    if ($seq_command eq 'L') {
	#external links have different syntax, so clear those first
	if ($seq_argument =~ m|://|) {
	    return "[$seq_argument]";
	};

	#first, look for text
	my $text;
	if ($seq_argument =~ /^(.+?)\|(.+)/) {
	    $text = $1;
	    $seq_argument = $2;
	}
	#next, look for sec (then text can be blank.
	if ($seq_argument =~ m:^(.*?)/(\"?)(.+)\2:) {
	    $seq_argument = "$1#$3";
	} elsif ($seq_argument =~ /^\"(.+)\"$/) {
	    $seq_argument = "#$1";
	};
	#replace perl :: with Wiki /
	$seq_argument =~ s{::}{/}g;
	if ($text) {
	    return "[[$seq_argument|$text]]";
	} else {
	    return "[[$seq_argument]]";
	};

    }
    warn "sequence is $seq_command $seq_argument";
};

sub begin_pod{
    my $parser = shift;
    my $out_fh = $parser->output_handle();
    print $out_fh "<!--\n",
    "  -- This page is automatically generated from the POD documentation in CVS.\n",
    "  -- Any edits made here will be automatically overridden.\n",
    "  -->\n__NOEDITSECTION__\n";
}

# sub end_pod{
#     my $parser = shift;
#     my $out_fh = $parser->output_handle();
#     print $out_fh "\n[[Category:POD documentation]]\n";
# }
1;
