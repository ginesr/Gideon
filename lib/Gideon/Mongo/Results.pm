package Gideon::Mongo::Results;

use strict;
use warnings;
use Try::Tiny;
use Moose;

with 'Gideon::Results';

__PACKAGE__->meta->make_immutable();
