package Basic::Gideon;

use Moose;
use Gideon;

extends qw(Gideon);

store 'test:destination';

__PACKAGE__->meta->make_immutable();