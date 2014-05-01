package Example::My::Person;

use Moose;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;

extends 'Gideon::DBI';
store 'mysql_master:gideon_j1';

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

has_many 'Example::My::Address' => (
    predicate => 'find_by_address',
    type      => 'DBI',
    join_on   => [ 'id', 'person_id' ],
);

__PACKAGE__->meta->make_immutable();
