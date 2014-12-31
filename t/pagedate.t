use Test::More;
use lib 'lib';

BEGIN {
  *CORE::GLOBAL::time = \&fake_time;
};

use PageDate;

sub fake_time() {
  return 1360817773;
};

my $month = PageDate->new;
my $year = PageDate->new(annual=>1);
my $year2 = PageDate->new(date=>{years=>1});

is ($month->page, '2013-02', 'month page');
is ($year->page, '2012', 'year page');
is ($year2->page, '2012-02', 'year page');

is ($month->anchor, '/2013-02', 'month anchor');
is ($year->anchor, '/2012', 'year anchor');

is ($month->link, '[[/2013-02|February]]', 'month link');
is ($year->link, '[[/2012|2012]]', 'year link');

done_testing;
