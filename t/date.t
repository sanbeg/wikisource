use Test::More;
use lib 'lib';

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
is($date->day, 13, 'got day');

my $jan = Date->new(days=>30);
is($jan->{date}, 20130014, 'got offset fake time');
is($jan->year, 2013, 'got offset year');
is($jan->month, 1, 'got offset month');
is($jan->month_name, 'January', 'got offset month name');

cmp_ok($jan, '<', $date, 'offset < date');
cmp_ok($date, '>', $jan, 'date > offset');
cmp_ok($date, '==', $date, 'date > offset');

my $nov = Date->new(months=>3);
is($nov->year, 2012, 'got year');
is($nov->month, 11, 'got month');
is($nov->month_name, 'November', 'got month name');

my $prev_year = Date->new(years=>1);
is($prev_year->year, 2012, 'got prev year');
is($prev_year->month, 2, 'got month');
is($prev_year->month_name, 'February', 'got month name');
is($prev_year->day, 13, 'got day');

done_testing;
