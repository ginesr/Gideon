package Gideon::DB::Driver::Mongo;

use Moose;
use warnings;
use Gideon::Error::Simple;
use MongoDB;

extends 'Gideon::DB::Driver';

has 'type' => ( is => 'ro', isa => 'Str', default  => 'MONGO' );

sub connect {
    my $self = shift;
    return MongoDB::Connection->new;
}

__PACKAGE__->meta->make_immutable();
