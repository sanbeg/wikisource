use Test::More;
use lib 'lib';
use Link;

my $page = 'Example';
my %data = ( 
  '[[/xx]]' => "[[$page/xx]]",
  '<nowiki>[[/xx]]</nowiki>' => undef,
  '<pre>[[/xx]]</pre>' => undef,
  '<123>' => undef,
 );

while (my ($before,$after) = each %data) {
  my ($before, $after) = ($before, $after);
  $after //= $before;
  Link::relocate($page,$before);
  is ($before, $after, "dst: $before");
};

my %src_data = ( 
  '[[#xx]]' => "[[$page#xx]]",
  '<nowiki>[[/xx]]</nowiki>' => undef,
  '<pre>[[/xx]]</pre>' => undef,
  '<123>' => undef,
 );

while (my ($before,$after) = each %src_data) {
  my ($before, $after) = ($before, $after);
  $after //= $before;
  Link::relocate_src($page,['xx'],$before);
  is ($before, $after, "src: $before");
};

done_testing;
