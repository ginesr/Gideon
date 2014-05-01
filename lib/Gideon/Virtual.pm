package Gideon::Virtual;

use strict;
use warnings;
use Moose;
use Gideon::Error;
use Carp qw(cluck carp croak);
use Gideon::Virtual::Results;

extends 'Gideon';

sub find_all {

    my $class = shift;
    my ( $args, $config ) = $class->decode_params(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    $args = $class->filter_rules($args);

    try {

        my $cache_key;

        my $fields = $class->metadata->get_columns_from_meta();
        my $map    = $class->metadata->map_args_with_alias($args);
        my $order  = $config->{order_by} || [];
        my $limit  = $config->{limit} || '';

        my $destination = $class->get_store_destination();
        my $provider    = $class->get_store_args();

        $provider->supports($destination);
        $provider->results( Gideon::Virtual::Results->new( package => $class ) );
        $provider->class($class);

        if ( $class->cache_registered ) {
            $cache_key = $class->generate_cache_key( $destination, $args );
            if ( my $cached_results = $class->cache_lookup($cache_key) ) {
                $provider->results($cached_results);
                return wantarray ? $provider->results->records : $provider->results;
            }
        }

        my $results = $provider->execute( $destination, $args, $map );

        if ($cache_key) {
            $class->cache_store( $cache_key, $results );
        }

        return wantarray ? $provider->results->records : $provider->results;

    }
    catch {
        my $e = shift;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak $e;
    };

}

sub cache_store {

    my $self = shift;
    my $key  = shift;
    my $what = shift;

    my $class = (ref $self) ? ref $self : $self;

    return Gideon->cache_store( $key, $what, $class );

}

sub generate_cache_key {

    my $self = shift;
    my $dest = shift;
    my $args = shift || {};

    my $vals = join '_', map { $_ . '-' . $args->{$_} } keys %{$args};
    my $key = $self->signature_for_cache . $dest . $vals;    # uniqueness generated with sql query and filters

    my $module = $self->get_cache_module;
    return $module->digest($key);

}

sub map_meta_with_row {

    my $class = shift;
    my $row   = shift;
    my $map   = {};

    foreach my $r ( keys %{$row} ) {
        my ( $table, $col ) = split( /\./, $r );
        my $attribute = $class->metadata->get_attribute_for_column($col);
        next unless $attribute;
        $map->{$attribute} = $r;
    }

    return $map;

}

sub is_debug {
    return $Gideon::EXCEPTION_DEBUG
}

__PACKAGE__->meta->make_immutable();
