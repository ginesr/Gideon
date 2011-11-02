
package Example::Driver::Mongo;

use strict;
use warnings;
use Example::Error::Simple;
use Mouse;
use MongoDB;

extends 'Gideon::DB::Driver';

has 'type' => ( is => 'ro', isa => 'Str', default  => 'MONGO' );

sub connect {
    my $self = shift;
    return MongoDB::Connection->new;
}

1;
