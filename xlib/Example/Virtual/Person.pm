package Example::Virtual::Person;

use Moose;
use Gideon::DBI;
use Example::Virtual::Address;

extends 'Gideon::DBI';
store 'mysql:gideon_virtual_person';

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

has '_address' => (
    traits => ['Array'],
    is => 'rw',
    isa => 'ArrayRef[Example::Virtual::Address]',
    handles => {
        has_address => 'count',
        find_address => 'first',
        address_is_empty => 'is_empty',
        addresses => 'elements',
        address => 'get',
    },
    default => sub {
        my $self = shift;
        my @list = Example::Virtual::Address->find_all( person_id => $self->id );
        return \@list;
    },
    lazy => 1,
);

__PACKAGE__->meta->make_immutable();
