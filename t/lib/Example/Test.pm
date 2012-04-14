
package Example::Test;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Mouse;

extends 'Gideon::DBI';
store 'pool:gideon_t1';

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

1;