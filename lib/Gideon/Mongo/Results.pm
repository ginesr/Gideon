package Gideon::Mongo::Results;

use strict;
use warnings;
use Try::Tiny;
use Moose;

with 'Gideon::Results';

sub remove {

    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {

        if ( $self->has_no_records ) {
            return 0;
        }

    }
    catch {
        my $e = shift;
    }    
}

sub update {

    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {

        if ( $self->has_no_records ) {
            return 0;
        }

    }
    catch {
        my $e = shift;
    }
}

__PACKAGE__->meta->make_immutable();
