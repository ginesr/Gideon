package Example::Test3;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Moose;

extends 'Gideon::DBI';
store 'mysql_server:gideon_t1';

has 'id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);

has 'name' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'name',
    metaclass => 'Gideon'
);

has 'value' => (
    is        => 'rw',
    isa       => 'Str',
    column    => 'value',
    metaclass => 'Gideon'
);

has 'type' => (
    is        => 'rw',
    isa       => 'Num',
    column    => 'type',
    metaclass => 'Gideon'
);

has 'type' => (
    is        => 'rw',
    isa       => 'Num',
    column    => 'type',
    metaclass => 'Gideon'
);

has 'period' => (
    is        => 'rw',
    isa       => 'Str',
    column    => 'period',
    metaclass => 'Gideon'
);

__PACKAGE__->meta->make_immutable();