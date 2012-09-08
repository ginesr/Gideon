
package Example::Virtual::PersonJoinAddress;

use strict;
use warnings;
use Moose;
use Gideon::Virtual;
use Gideon::Meta::Attribute::Virtual;

extends 'Gideon::Virtual';
store 'my_virtual_store:person_with_address';

has 'person_id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    alias       => 'n',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);

has 'address_id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    alias       => 'd',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);

has 'name' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'name',
    alias     => 'n',
    metaclass => 'Gideon'
);

has 'address' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'address',
    alias     => 'd',
    metaclass => 'Gideon'
);

1;