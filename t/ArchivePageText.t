use Test::More;
use lib 'lib';

use ArchivePageText;

my $hello = ArchivePageText->new('hello world');
is($hello->text, 'hello world');

my $emptybuf='';
open my($emtpyfh), '<', \$emptybuf;
$hello->merge($emptyfh, [], 2);
is($hello->text, 'hello world');

my $new_text = q[
discussion
=A=
n1
n2
=B=
n3
n4
=C=
];

my $old_text = q[
archive
=A=
o1
=D=
];

my $old_page = ArchivePageText->new($old_text);
open my($newfh), '<', \$new_text;
$old_page->merge($newfh, [[4,4],[7,7]], 1);
foreach my $piece (qw(archive o1 n1 n3 A B D)) {
    like($old_page->text, qr/$piece/, "archived $piece");
}
foreach my $piece(qw(n2 n4 C)) {
    unlike($old_page->text, qr/$piece/, "didn't archive $piece");
}

done_testing;
