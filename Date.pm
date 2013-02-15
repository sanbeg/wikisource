package Date;
use strict;

my @months=qw(January February March April May June July August September October November December);

sub new {
  my $class = shift;
  my %opt = @_;

  my $date = $opt{date};
  unless (defined $date) {
    my @now = localtime(time()-60*60*24*$opt{days});
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
    $date = $d+$m*100+$y*10_000;
  }

  bless { date => $date }, $class;
};

sub year {
  int( $_[0]{date} / 10_000 );
};
sub month {
  int(($_[0]{date} % 10_000) / 100)+1;
};

sub month_name {
  my $self = shift;
  return $months[ $self->month - 1 ];
};

sub compare {
  my ($self, $other, $reverse) = @_;
  my $rv = $self->{date} <=> $other->{date};
  $rv *= 1 if $reverse;
  return $rv;
};

use overload '<=>' => \&compare;

1;
