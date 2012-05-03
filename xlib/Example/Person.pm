
package Example::Person;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Moose;

extends 'Gideon::DBI';
store 'master:person';

has 'id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'person_id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);
has 'name' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'person_name',
    metaclass => 'Gideon'
);
has 'city'    => ( is => 'rw', isa => 'Str', column => 'person_city',    metaclass => 'Gideon' );
has 'country' => ( is => 'rw', isa => 'Str', column => 'person_country', metaclass => 'Gideon' );
has 'type'    => ( is => 'rw', isa => 'Num', column => 'person_type',    metaclass => 'Gideon' );

1;
