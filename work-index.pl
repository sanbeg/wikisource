#! /usr/bin/perl -w

use strict;
use Getopt::Long;
use Encode;
use lib 'archive'; #for password file.

use lib '../MediaWiki-EditFramework/lib';
use MediaWiki::EditFramework;
use passwd;
use open ':utf8';
use open ':std';

my $be_anon;
my $do_edit;

#skip various disambig pages
my %bl = (
'Category:Mainspace disambiguation pages' => 1,
'Category:Case disambiguation pages' => 1,
'Category:Versions pages' => 1,
'Category:Translations pages' => 1,
);

GetOptions ('do_edit' => \$do_edit ) or die;

my $wiki = MediaWiki::EditFramework->new('en.wikisource.org');
$be_anon = 1 unless $do_edit;
$wiki->login($::username, $::password) unless $be_anon;


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
    foreach my $c ( @{ $data->{categories} } ) {
      push @cl, $c->{title};
      ++ $bl if $bl{ $c->{title} } ; #count blacklisted cats
    };
    $page_cats{ $data->{title} } = \@cl unless $bl;
  };
  @batch = ();
};

# my $text='';
# open my($fh), '>', \$text;
# my $stdout = select $fh;

foreach my $letter ( 'a' .. 'z' ) {
  my $prefix = ucfirst "a$letter";
  print "\n== $prefix ==\n\n";

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
    get_cats if @batch == 10;
  };
  
  get_cats if @batch;
  
  #while ( my ($page, $cats) = each %page_cats ) {
  foreach my $page ( sort keys %page_cats ) {
    my $cats = $page_cats{$page};

    print "* [[$page]]";
    if (@$cats) {
      print" (",
	join(', ', map("[[:$_|]]",@$cats)),
	")";
    };
    print "\n";
  };

  %page_cats = ();
  sleep 1;

}

# close $fh;
# $wiki->get_page ('User:Sanbeg/a')->edit($text, 'Create index of works');
