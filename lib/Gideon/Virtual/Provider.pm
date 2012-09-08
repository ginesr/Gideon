
package Gideon::Virtual::Provider;

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Carp qw(croak);
use Data::Dumper qw(Dumper);
use Gideon::Error;
use Set::Array;

has 'driver' => ( is => 'rw' );
has 'class' => ( is => 'rw', isa => 'Str' );
has 'results' => ( is => 'rw', isa => 'Set::Array' );

sub cache_key {
    my $self = shift;
    my $name = shift;
    return $name;
}

sub execute {
    
    my $self = shift;
    my $name = shift;
    my $fiters = shift;
    
    $self->supports($name);
    my $method = $self->method($name);
    $self->$method($fiters);
    
    return $self->results;
    
}

sub supports {
    
    my $self = shift;
    my $name = shift;
    
    my $stores_hash = $self->virtual_stores;
    
    if ( exists $stores_hash->{ $name } ) {
        return 1;
    }
    
    Gideon::Error->throw('your provider does not support ' . $name );
}

sub method {
    my $self = shift;
    my $name = shift;   
    my $stores_hash = $self->virtual_stores;
    return $stores_hash->{ $name };
}

sub virtual_stores {die('implement in your class')}

1;