package Basic::Gideon;

use strict;
use Gideon;
use Moose;

extends qw(Gideon);

store 'test:destination';

__PACKAGE__->meta->make_immutable();