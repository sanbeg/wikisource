package Date;
use strict;

my @months=qw(January February March April May June July August September October November December);

sub set {
  my $self = shift;
  my $date = shift;

  if (ref $date) {
    $self->{date} = $date->{d}+$date->{m}*100+$date->{y}*10_000;
  } else {
    $self->{date} = $date ;
  }
}

sub unset {
  my $self = shift;
  if (ref $self) {
    $self->{date} = 0;
  } else {
    $self = bless {date=>0}, $self;
  };
  return $self;
}

sub new {
  my $class = shift;
  my %opt = @_;

  my %self;

  if (defined $opt{date}) {
    set(\%self, $opt{date});
  } else {
    my $delta = (defined($opt{days})?$opt{days}:0) * 60*60*24;
    my @now = localtime(time()-$delta );
    my $d = $now[3];
    my $m = $now[4];
    my $y = $now[5] + 1900;

    if ($opt{months}) {
      $m -= $opt{months};
      while ($m < 0) {
	-- $y;
	$m += 12;
      }
    };
    if ($opt{years}) {
	$y -= $opt{years};
    };
    $self{date} = $d+$m*100+$y*10_000;
  }

  bless \%self, $class;
};

sub year  {
  int( $_[0]{date} / 10_000 )
};
sub month {
  int(($_[0]{date} % 10_000) / 100)+1
};
sub day {
  $_[0]{date} % 100
};

sub month_name {
  my $self = shift;
  return $months[ $self->month - 1 ];
};

sub compare {
  my ($self, $other, $reverse) = @_;
  my $rv = $self->{date} <=> $other->{date};
  $rv *= -1 if $reverse;
  return $rv;
};

use overload '<=>' => \&compare;

1;
