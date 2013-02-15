use Test::More;
use lib '.';

BEGIN {
  *CORE::GLOBAL::time = \&fake_time;
};

use Date;

sub fake_time() {
  return 1360817773;
};

my $date = Date->new;

is($date->{date}, 20130113, 'got fake time');
is($date->year, 2013, 'got year');
is($date->month, 2, 'got month');
is($date->month_name, 'February', 'got month name');

my $jan = Date->new(days=>30);
is($jan->{date}, 20130014, 'got offset fake time');
is($jan->year, 2013, 'got offset year');
is($jan->month, 1, 'got offset month');
is($jan->month_name, 'January', 'got offset month name');

cmp_ok($jan, '<', $date, 'offset < date');
cmp_ok($date, '>', $jan, 'date > offset');
cmp_ok($date, '==', $date, 'date > offset');

done_testing;
