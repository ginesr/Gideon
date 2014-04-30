package Example::Lazy;

use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Moose;

extends 'Gideon::DBI';
store 'mysql:gideon_t4';

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

has 'order' => (
    is        => 'rw',
    isa       => 'Num',
    column    => 'order',
    metaclass => 'Gideon',
    lazy      => 1,
    default   => sub {
        my $self = shift;
        my $max = __PACKAGE__->function('max', 'order' );
        return $max + 1;
    }
);

__PACKAGE__->meta->make_immutable();
