package Link;

#relocate relative links in archived sections
sub relocate {
    my $page = shift;

    for (@_) {
	my $strip_text=sub( $ ) {
	    push (@strip_state, $_[0]);
	
	    return "<$#strip_state>";
	};

	next unless m{\Q[[/};

	s{(<(nowiki|pre)\s*>(.*?)</\2\s*>|<[0-9]+>)}{$strip_text->($1)}ge;
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
    foreach my $section (@$closed_sections) {
      s/\Q[[#$section\E(\|.+?)?\Q]]\E/[[$page#$section$1/;
    }
  }
}
1;
