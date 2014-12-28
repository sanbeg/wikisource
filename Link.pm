package Link;

my @strip_state;

sub _strip_text( $ ) {
  push (@strip_state, $_[0]);
  return "<$#strip_state>";
}

#relocate relative links in archived sections
sub relocate {
    my $page = shift;

    for (@_) {
	next unless m{\Q[[/};

	s{(<(nowiki|pre)\s*>(.*?)</\2\s*>|<[0-9]+>)}{_strip_text($1)}ge;
	s{\Q[[/}{[[$page/}g;

	s{<([0-9]+)>}{$strip_state[$1]}ge;
	@strip_state = ();
    }
}

#relocate links to moved sections
sub relocate_src {
  my $page = shift;
  my $closed_sections = shift;
  for (@_) {
    next unless m{\Q[[#};
    s{(<(nowiki|pre)\s*>(.*?)</\2\s*>|<[0-9]+>)}{_strip_text($1)}ge;
    foreach my $section (@$closed_sections) {
      s{\Q[[#$section\E(\|.+?|)?\Q]]\E}{[[$page#$section$1]]};
    }
    s{<([0-9]+)>}{$strip_state[$1]}ge;
    @strip_state = ();
  }
}
1;
