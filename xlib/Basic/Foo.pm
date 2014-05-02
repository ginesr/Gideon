package Basic::Foo;

use Moose;
use Gideon;

extends qw(Gideon);

store 'test:bar';

__PACKAGE__->meta->make_immutable();