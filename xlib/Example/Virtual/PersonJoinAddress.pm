package Example::Virtual::PersonJoinAddress;

use Moose;
use Gideon::Virtual;

extends 'Gideon::Virtual';
store 'virtual:person_with_address';

has 'person_id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    alias       => 'person_id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon::Virtual'
);

has 'address_id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    alias       => 'address_id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon::Virtual'
);

has 'name' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'name',
    alias     => 'name',
    metaclass => 'Gideon::Virtual'
);

has 'address' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'address',
    alias     => 'address',
    metaclass => 'Gideon::Virtual'
);

__PACKAGE__->meta->make_immutable();
