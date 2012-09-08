
package Gideon::Virtual;

use strict;
use warnings;
use Moose;
use Gideon;
use Gideon::Error;
use Carp qw(cluck carp croak);
use Set::Array;
use Gideon::Virtual::Results;

extends 'Gideon';

use constant CACHE_MINS_TTL => 1;

has 'provider' => ( is => 'rw' );

sub find_all {

    my $class = shift;
    my ( $args, $config ) = $class->decode_params(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    $args = $class->filter_rules($args);

    try {

        my $cache_key;
        
        my $fields = $class->get_columns_from_meta();
        my $map    = $class->map_args_with_meta( $args );
        my $order  = $config->{order_by} || [];
        my $limit  = $config->{limit} || '';
        
        my $destination = $class->get_store_destination();
        my $store = $class->get_store_args();
        
        $store->provider->supports($destination);

        if ( $class->cache_registered ) {
            $cache_key = $store->provider->cache_key($destination);
            $class->cache_lookup( $cache_key );
        }

        $store->provider->results(Set::Array->new);
        $store->provider->class($class);

        my $results = $store->provider->execute($destination,$args);
        
        if ( $cache_key ) {
            $class->cache_store( $cache_key, $results );
        }
        
        my $virtual_results = Gideon::Virtual::Results->new(
            package    => $class,
            results     => $results 
        );

        return wantarray ? $results->flatten() : $virtual_results;

    }
    catch {
        my $e = shift;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak $e;
    };

}

sub cache_store {
    
    my $self = shift;
    my $key = shift;
    my $what = shift;
    
    return super( $key, $what, CACHE_MINS_TTL * 60)

}

1;