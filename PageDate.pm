package PageDate;
use Date;
our @ISA = 'Date';


sub set_annual {
    my $self = shift;
    $self->{annual} = shift;
}

sub page {
    my $self = shift;
    if (defined $self->{annual}) {
	my $archive_year = $self->year - $self->{annual};
	return $archive_year;
    } else {
	return sprintf "%d-%.2d", $self->year, $self->month;
    }
}


sub link {
    my $self = shift;
    my $anchor = '/' . $self->page;
    if (defined $self->{annual}) {
	$archive_summary = "[[$anchor|".($self->year-$self->{annual}) ."]]";
    } else {
	$archive_summary = "[[$anchor|". $self->month_name.   "]]";
    }
}

