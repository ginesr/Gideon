
package Gideon::DB::Driver::Mongo;

use strict;
use warnings;
use Gideon::Error::Simple;
use MongoDB;
use Mouse;

extends 'Gideon::DB::Driver';

has 'type' => ( is => 'ro', isa => 'Str', default  => 'MONGO' );

sub connect {
    my $self = shift;
    return MongoDB::Connection->new;
}

1;
