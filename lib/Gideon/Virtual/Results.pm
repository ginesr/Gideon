package Gideon::Virtual::Results;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Try::Tiny;
use Moose;
use Gideon::Error;
use Set::Array;

has 'results' => (
    is      => 'rw',
    isa     => 'Set::Array',
    handles => {
        'first'    => 'first',
        'last'     => 'last',
        'is_empty' => 'is_empty',
        'length'   => 'length',
        'flatten'  => 'flatten',
    }
);
has 'package' => ( is => 'rw', isa => 'Str' );

sub map {

    my $self = shift;
    my $code = shift;
    
    unless ( ref($code) ) {
        Gideon::Error->throw('grep() needs a fuction as argument');
    }
    if ( ref($code) ne 'CODE' ) {
        Gideon::Error->throw('grep() argument is not a function reference');
    }
        
    my $filtered = Set::Array->new;
    
    my @list = $self->results->flatten();
    my @filter = grep { defined $_ } map { (&$code) ? $_ : undef } @list;
    
    $filtered->push(@filter);
    
    my $results = __PACKAGE__->new(
        'package' => $self->package,
        'results' => $filtered 
    );
    
    return $results;
    
}

sub grep {
    
    my $self = shift;
    my $code = shift;
    
    unless ( ref($code) ) {
        Gideon::Error->throw('grep() needs a fuction as argument');
    }
    if ( ref($code) ne 'CODE' ) {
        Gideon::Error->throw('grep() argument is not a function reference');
    }
        
    my $filtered = Set::Array->new;
    
    my @list = $self->results->flatten();
    my @filter = grep { &$code } @list;
    
    $filtered->push(@filter);
    
    my $results = __PACKAGE__->new(
        'package' => $self->package,
        'results' => $filtered 
    );
    
    return $results;
    
}

sub remove {
    
    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {
        
        if ($self->results->is_empty) {
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
        
        if ($self->results->is_empty) {
            return 0
        }        

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        # implement update

    }

}

__PACKAGE__->meta->make_immutable();
