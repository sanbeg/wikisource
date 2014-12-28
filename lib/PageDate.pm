package PageDate;
use strict;
use Date;

sub new {
    my $class = shift;
    my %opts = @_;
    my %date_opts;
    %date_opts = %{$opts{date}} if defined $opts{date};
    $date_opts{years} = $opts{annual} if $opts{annual};
    bless {date=>Date->new(%date_opts), annual=>$opts{annual}}, $class;
}


sub page {
    my $self = shift;
    if (defined $self->{annual}) {
	return $self->{date}->year;
    } else {
	return sprintf "%d-%.2d", $self->{date}->year, $self->{date}->month;
    }
}

sub anchor {
    my $self = shift;
    return '/' . $self->page;
}

sub link {
    my $self = shift;
    my $anchor = '/' . $self->page;
    if (defined $self->{annual}) {
	return "[[$anchor|". $self->{date}->year ."]]";
    } else {
	return "[[$anchor|". $self->{date}->month_name.   "]]";
    }
}

1;
