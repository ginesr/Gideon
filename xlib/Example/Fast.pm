package Example::Fast;

use Moose;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;

extends 'Gideon::DBI';
store 'mysql_server:gideon_t10Cache';

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

__PACKAGE__->meta->make_immutable();
