package Example::My::Address;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Mouse;

extends 'Gideon::DBI';
store 'mysql_master:gideon_j2';

has 'id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);
has 'person_id' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Num',
    column    => 'person_id',
    metaclass => 'Gideon'
);

has 'street' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'address',
    metaclass => 'Gideon'
);

has 'city' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'address',
    metaclass => 'Gideon'
);

1;
