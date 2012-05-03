
package Example::Driver::Storable;

use strict;
use warnings;
use Storable qw();
use Example::Error::Simple;
use Moose;

extends 'Gideon::DB::Driver';

has 'db'   => ( is => 'rw', isa => 'Str', required => 1 );
has 'type' => ( is => 'ro', isa => 'Str', default  => 'STORABLE' );

sub connect {
    my $self = shift;
    return $self->db;
}

1;
