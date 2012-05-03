
package Mongo::Person;

use strict;
use warnings;
use Gideon::Mongo;
use Gideon::Meta::Attribute::Mongo;
use Moose;

extends 'Gideon::Mongo';
store 'gideon:person';

has 'id' => (
    is          => 'rw',
    isa         => 'Num',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);
has 'name' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    metaclass => 'Gideon'
);
has 'city'    => ( is => 'rw', isa => 'Str', metaclass => 'Gideon' );
has 'country' => ( is => 'rw', isa => 'Str', metaclass => 'Gideon' );
has 'type'    => ( is => 'rw', isa => 'Num', metaclass => 'Gideon' );

1;
