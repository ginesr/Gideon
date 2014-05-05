package Example::Virtual::Address;

use Moose;
use Gideon::DBI;
use Example::Virtual::Person;

extends 'Gideon::DBI';
store 'mysql:gideon_virtual_address';

has 'id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);

has 'person_id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'person_id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);

has 'address' => (
    is        => 'rw',
    isa       => 'Str',
    column    => 'address',
    metaclass => 'Gideon'
);

has 'person' => (
    is => 'rw',
    isa => 'Example::Virtual::Person',
    default => sub {
        my $self = shift;
        return Example::Virtual::Person->find( id => $self->person_id )
    },
    lazy => 1,
);

__PACKAGE__->meta->make_immutable();
