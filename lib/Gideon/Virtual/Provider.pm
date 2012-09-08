
package Gideon::Virtual::Provider;

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Exporter qw(import);
use Carp qw(croak);
use Data::Dumper qw(Dumper);
use Gideon::Error;
use Set::Array;

my $__virtual_store = {};

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
    my $map = shift;
    
    $self->supports($name);
    my $method = $self->method($name);
    &$method($self,$fiters,$map);
    
    return $self->results;
    
}

sub supports {
    
    my $self = shift;
    my $name = shift;
    my $package = ref $self;
    
    my $stores_hash = $__virtual_store->{ $package };
    
    if ( exists $stores_hash->{ $name } ) {
        return 1;
    }
    
    Gideon::Error->throw('your provider does not support ' . $name );
}

sub method {
    my $self = shift;
    my $name = shift;   
    my $package = ref $self;
    my $stores_hash = $__virtual_store->{ $package };
    return $stores_hash->{ $name };
}

# Imports ----------------------------------------------------------------------

no strict 'refs';
no warnings 'redefine';

sub import {

    my ($class) = @_;
    my $caller = caller;

    *{"${caller}::virtual_store"} = \&virtual_store;

}

use strict 'refs';
use warnings 'redefine';

sub virtual_store($$) {
    my $store = shift || return undef;
    my $method = shift;
    my $caller = caller;
    $__virtual_store->{$caller}->{$store} = $method;
}

__PACKAGE__->meta->make_immutable();