#! /usr/bin/perl -w

use strict;
use Getopt::Long;
use Encode;
use lib 'archive'; #for password file.

use lib '../MediaWiki-EditFramework/lib';
use MediaWiki::EditFramework;
use passwd;
# use open ':utf8';
# use open ':std';

my $be_anon;
my $do_edit;
my $comment = 'Create index of works';
#skip various disambig pages
my %bl = (
	  'Category:Mainspace disambiguation pages' => 1,
	  'Category:Case disambiguation pages' => 1,
	  'Category:Versions pages' => 1,
	  'Category:Translations pages' => 1,
	 );

my ($username, $password);
my $l1 = 'a';

GetOptions (
	    'letter=s' => \$l1,
	    'edit!' => \$do_edit,
	    'comment=s' => \$comment,
	    'username=s'=>\$username, 'password=s'=>\$password,
	   ) or die;

die "Invalid letter: $l1" unless $l1 =~ m/^[a-z]$/;

my $wiki = MediaWiki::EditFramework->new('en.wikisource.org');
$be_anon = 1 unless $do_edit;

$username //= $::username;
$password //= $::password;
$wiki->login($username, $password) unless $be_anon;

#$wiki->write_prefix('User:Sanbeg/');
#$wiki->{text_dump_dir} = 'tmp.d';

my %page_cats;
my @batch;

sub get_cats {
  my $cats = $wiki->api->api({
    action => 'query',
    titles => join('|', @batch),
    prop => 'categories',
    clshow => '!hidden',
  });

  while ( my ($pid, $data ) = each %{ $cats->{query}{pages} } ) {
    my $bl=0;
    my @cl;

    if (defined $data->{categories}) {
      #warn "Got cats for $data->{title}:" . @{ $data->{categories} };
      foreach my $c ( @{ $data->{categories} } ) {
	push @cl, $c->{title};
	++ $bl if $bl{ $c->{title} } ; #count blacklisted cats
      };
    } else {
      warn "No cats for $data->{title}";
    }
    $page_cats{ $data->{title} } = \@cl unless $bl;
  };
  @batch = ();
};

my $text = '<div style="clear:right; margin-bottom:.5em; float:right; padding:.5em 0 .8em 1.4em; background:none;">__TOC__</div>';

foreach my $letter ( 'a' .. 'z' ) {
  my $prefix = ucfirst "$l1$letter";
  my $subtext = "\n== $prefix ==\n\n";
  my $count = 0;

  my $articles = $wiki->api->list({
    action => 'query',
    list => 'allpages',
    apfrom => $prefix,
    apprefix => $prefix,
    apfilterredir => 'nonredirects',
    aplimit => 500,
  });

  foreach my $page ( @$articles ) {
    next if $page->{title} =~ m:/:; #skip sub pages
    push @batch, $page->{title};
    get_cats if @batch; #should allow batching, but seem to miss a lot of cats
  };

  get_cats if @batch;

  #while ( my ($page, $cats) = each %page_cats ) {
  foreach my $page ( sort keys %page_cats ) {
      #$page = decode_utf8($page);
      my $cats = $page_cats{$page};

      $subtext .= "* {{works-title|[[$page]]}}";
      if (@$cats) {
	  $subtext .= " &mdash; (".
	    join(', ', map("[[:$_|]]",@$cats)).
	    ")";
      };
      $subtext .=  "\n";
      ++ $count;
  };
  $text .= $subtext if $count > 0;

  %page_cats = ();
  select(undef,undef,undef,0.25);
}

open T, '>tmp';
print T encode_utf8(decode_utf8($text));

if ($do_edit) {
  #close $fh;
  $wiki->get_page ("Wikisource:Works-\u$l1")->edit($text, $comment);
}

