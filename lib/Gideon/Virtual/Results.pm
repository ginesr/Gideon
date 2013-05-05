package Gideon::Virtual::Results;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Try::Tiny;
use Moose;
use Gideon::Error;
use List::MoreUtils qw(uniq);

with 'Gideon::Results';

sub remove {
    
    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {
        
        if ($self->has_no_records) {
            return 0
        }

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        # implement remove
        
    }
    
}

sub update {

    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {
        
        if ($self->has_no_records) {
            return 0
        }        

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        # implement update

    }

}

__PACKAGE__->meta->make_immutable();
