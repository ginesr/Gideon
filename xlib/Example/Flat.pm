package Example::Flat;

use strict;
use warnings;
use Gideon::Storable;
use Gideon::Meta::Attribute::Storable;
use Mouse;

extends 'Gideon::Storable';
store 'disk:flat';

has 'id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);

has 'value' => (
    is        => 'rw',
    isa       => 'Str',
    column    => 'value',
    metaclass => 'Gideon'
);

1;