
package Gideon::Virtual::Provider;

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Exporter qw(import);
use Carp qw(croak);
use Data::Dumper qw(Dumper);
use Gideon::Error;

my $__virtual_store = {};

has 'driver' => ( is => 'rw' );
has 'class' => ( is => 'rw', isa => 'Str' );
has 'results' => ( is => 'rw', isa => 'Gideon::Virtual::Results' );

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

sub args_for_new_object {
    
    my $class = shift;
    my $package = shift;
    my $row   = shift;
    
    my $map = $class->map_meta_with_row($package,$row);
    return map { $_ => $row->{ $map->{$_} } } ( keys %{ $map } );
    
}

sub map_meta_with_row {

    my $class = shift;
    my $package = shift;
    my $row   = shift;
    my $map   = {};

    foreach my $col ( keys %{$row} ) {
        my $attribute = $package->metadata->get_attribute_for_alias($col);
        next unless $attribute;
        $map->{$attribute} = $col;
    }

    return $map;

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
