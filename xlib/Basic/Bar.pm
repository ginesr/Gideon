package Basic::Bar;

use Moose;
use Gideon;

extends qw(Gideon);

store 'some:foo';

__PACKAGE__->meta->make_immutable();