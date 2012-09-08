
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
        my $provider = $class->get_store_args();
                
        $provider->supports($destination);
        $provider->results(Set::Array->new);
        $provider->class($class);
                
        my $virtual_results = Gideon::Virtual::Results->new(
            package  => $class
        );
        
        if ( $class->cache_registered ) {
            $cache_key = $class->generate_cache_key($destination,$args);
            if (my $cached_results = $class->cache_lookup( $cache_key ) ) {
                $virtual_results->results($cached_results);
                return wantarray ? $cached_results->flatten() : $virtual_results;
            }
        }
        
        my $results = $provider->execute($destination,$args,$map);
        $virtual_results->results($results);
        
        if ( $cache_key ) {
            $class->cache_store( $cache_key, $results );
        }

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
    
    return Gideon->cache_store( $key, $what, CACHE_MINS_TTL * 60);

}

sub generate_cache_key {
    
    my $self = shift;
    my $dest = shift;
    my $args = shift || {};

    my $vals = join '_', map { $_ . '-' . $args->{$_} } keys %{ $args };
    my $key = $self->signature_for_cache . $dest . $vals; # uniqueness generated with sql query and filters

    my $module = $self->get_cache_module;
    return $module->digest($key);

}

__PACKAGE__->meta->make_immutable();
