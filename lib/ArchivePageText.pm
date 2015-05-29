package ArchivePageText;
use strict;
use Carp;

my $heading_re = qr/^(\=+)\s*(.+?)\s*\1$/;

sub new {
    my ($class, $text) = @_;
    croak "Missing text" unless defined $text;
    $text .= "\n" unless $text =~ m/\n$/;
    bless {text=>$text}, $class;
}

sub text {
    my $self = shift;
    return $self->{text};
}

sub merge {
    my ($self, $page_fh, $closed_sections_ref, $header_level) = @_;

    my %merge_text;
    my @majors;
    my $major = '';

    #slurp existing entries from subpage
    open my($fh), '<', \$self->{text} or die "couldn't open handle: $!";
    while (<$fh>) {
	/$heading_re/ and do {
	    my $level = length($1);
	    if ($level <= $header_level) {
		$major = $2;
		push @majors, $major;
	    }
	};
	$merge_text{$major} .= $_;
    }
    close $fh;

    my $buf_close = delete $merge_text{''};
    #make sure this is right for blank, no sections, sections
    my $have_merge_text = keys(%merge_text);
    my @close = @$closed_sections_ref;

    while (<$page_fh>) {
	last unless @close;
	/$heading_re/ and do {
	    my $level = length($1);
	    #print CFH if $level == 1;
	    if ($level <= $header_level) {
		if (defined $merge_text{$2}) {
		    $buf_close .= delete $merge_text{$2};
		    $buf_close .= "\n"; #was losing this somewhere.
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

    foreach my $heading (@majors) {
	$buf_close .= delete $merge_text{$heading} 
	  if (defined $merge_text{$heading});
    };
    foreach my $c (keys %merge_text) {
	warn "unused heading: $c";
    };

    $self->{text} = $buf_close;
}


1;
