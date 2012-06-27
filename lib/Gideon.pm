
=head1 NAME

Gideon - Datamapper written in Perl

=head1 DESCRIPTION

Gideon is intended to be an ORM completly written in Perl

=cut 

package Gideon;

use strict;
use warnings;
use Exporter qw(import);
use Data::Dumper qw(Dumper);
use Carp qw(cluck);
use Gideon::Error;
use Moose;
use Hash::MultiValue;
use 5.008_001;

our $VERSION = '0.02';
$VERSION = eval $VERSION;

our $EXCEPTION_DEBUG = 0;

my $__meta  = undef;
my $__store = {};
my $__stricts = {};
my $__cache = undef;
our %stores = ();
our $__pool  = undef;

has 'is_modified' => ( is => 'rw', isa => 'Bool', default => 0);
has 'is_stored' => ( is => 'rw', isa => 'Bool', default => 0, lazy => 1 );

sub BUILD {

    my $self = shift;
    my @args  = @_;

    $self->_init(@args);

}

sub register_store {
    my $class      = shift;
    my $store_name = shift;
    my @args       = @_;
    die 'register store is a class method' if ref $class;
    unless ( $class->store_registered($store_name,@args) ) {
        $stores{$store_name} = $args[0];
    }
    if ( grep { /strict/ } @args ) {
        $__stricts->{$store_name} = 1;
    }
    $class;    
}

sub register_cache {
    my $class = shift;
    my $module = shift;
    $__cache = $module;
}

sub find {
    my $class = shift;

    # overload in subclass
}

sub find_all {
    my $class = shift;

    # overload in subclass
}

sub save {
    my $class = shift;

    # overload in subclass
}

sub remove {
    my $class = shift;

    # overload in subclass
}

sub remove_all {
    my $class = shift;

    # overload in subclass    
}

sub cache_lookup {
    my $class = shift;

    # overload in subclass
}

sub filter_rules {

    my $class   = shift;
    my $args    = shift;
    my $options = shift || '';

    foreach ( keys %{$args} ) {
        $class->check_meta($_) unless $options =~ /skip_meta_check/;
        my $value_filtered = $class->trans_filters( $args->{$_} );
        $args->{$_} = $value_filtered;
    }

    return $args;

}

sub like {
    my $class = shift;
    my $string = shift || "";
    return '%' . $string . '%';
}

sub gte {
    my $class = shift;
    my $string = shift || "";
    return '>=' . $string;
}

sub lte {
    my $class = shift;
    my $string = shift || "";
    return '<=' . $string;
}

sub not {
    my $class = shift;
    my $string = shift || "";
    return '<>' . $string;

}

sub gt {
    my $class = shift;
    my $string = shift || "";
    return '>' . $string;

}

sub lt {
    my $class = shift;
    my $string = shift || "";
    return '<' . $string;

}

sub eq {
    my $class = shift;
    my $string = shift || "";
    return '=' . $string;

}

sub validate_order_by {

    my $class   = shift;
    my $config  = shift;
    my $options = shift || '';

    if ( ref($config) eq 'ARRAY' ) {
        $config = $class->_transform_sort_by_from_array( $config, $options );
    }
    if ( ref($config) eq 'HASH' ) {
        $config = $class->_transform_sort_by_from_hash( $config, $options );
    }
    unless ( ref($config) ) {
        $class->check_meta($config) unless $options =~ /skip_meta_check/;
        $config = $class->get_colum_for_attribute($config);
    }

    return $config;

}

sub check_for_config_in_params {
    
    my $class = shift;
    my @args  = @_;
    
    # func( one => 1, { options => 1 } )
    if ( ( scalar(@args) % 2 ) != 0 and ref( $args[-1] ) eq 'HASH' ) {
        return 1;
    }
    # func( undef, {} )
    if ( scalar(@args) == 2 and !defined $args[0] and ref( $args[-1] ) eq 'HASH' ) {
        return 1;
    }
    if ( scalar(@args) == 1 and ref( $args[-1] ) eq 'HASH' ) {
        return 1;
    }
        
    return;
}

sub decode_params {

    my $class  = shift;
    my @args   = @_;
    my $args   = {};
    my $config = {};

    # check if there are options passed, last argument as hashref
    if ( $class->check_for_config_in_params(@args) ) {
        $config = pop @args;
        if ( exists $config->{order_by} ) {
            $config->{order_by} = $class->validate_order_by( $config->{order_by} );
        }
    }

    unless ( defined $args[0] ) {
        @args = (); # passing undef in params trigger warnings
    }

    my $hash = Hash::MultiValue->new(@args);
    $args = {@args};

    foreach ( keys %{$args} ) {
        my @all = $hash->get_all($_);
        if ( scalar(@all) > 1 ) {
            $args->{$_} = \@all;
        }
    }
    
    return wantarray ? ( $args, $config ) : $args;

}

sub trans_filters {

    my $class  = shift;
    my $filter = shift;

    my @filters = ();

    unless ( ref($filter) ) {
        return $filter;
    }

    if ( ref($filter) eq 'ARRAY' ) {
        my @multi = ();
        foreach ( @{$filter} ) {
            my @filters = $class->_transform_filter( $_, @filters );
            my @pairs = ();
            foreach my $f (@filters) {
                foreach my $h ( keys %{$f} ) {
                    push @pairs, ( $h, $f->{$h} );
                }
            }
            push @multi, {@pairs};
        }
        @filters = @multi;
    }

    if ( ref($filter) eq 'HASH' ) {
        @filters = $class->_transform_filter( $filter, @filters );
    }

    return scalar @filters == 1 ? $filters[0] : \@filters;

}

sub transform_filter_values {

    my $class  = shift;
    my $type   = shift;
    my $values = shift;

    my @values = ();

    if ( ref $values eq 'ARRAY' ) {
        foreach my $filter_value ( @{$values} ) {
            push @values, $class->$type($filter_value);
        }
    } else {
        push @values, $class->$type($values);
    }

    return scalar @values == 1 ? $values[0] : \@values;
}

sub get_store_id {
    my $self  = shift;
    my $id = $self->_store_info;
    return $id;
}

sub get_store_destination {
    my $self  = shift;
    my ( $id, $dest ) = $self->_store_info;
    die 'invalid store \'' .$id . '\' from class '. $self .', use Gideon->register(\'' . $id . '\', ... )' unless $stores{$id};
    return $dest;
}

sub stores_for {
    my $self = shift;
    my $other = shift;
    my @stores = ();

    push @stores, $self->get_store_destination;
    push @stores, $other->get_store_destination;
    
    return wantarray ? @stores : join ',', @stores;
    
}

sub columns_meta_for {
    
    my $self = shift;
    my $other = shift;
    my @fields = ();
    
    my $myfields = $self->get_columns_from_meta();
    my $foreing = $other->get_columns_from_meta();
    
    push @fields, @{$myfields};
    push @fields, @{$foreing};
    
    return wantarray ? @fields : join ',', @fields;    
    
}

sub get_store_args {
    
    my $self  = shift;
    my $node  = shift;

    my $id    = $self->_store_info;
    my $store = $stores{$id};
    my $pkg   = $self->_get_pkg_name;

    die 'invalid store \'' .$id . '\' from class '. $self .', use Gideon->register(\'' . $id . '\', ... )' unless $store;
    
    if ( ref($store) eq 'Gideon::Connection::Pool' ) {
        return $self->get_store_from_pool( $store, $node );
    }
    if ($node and !defined $__pool->{$pkg}) {
        die "can't use $node without pool configuration";
    }
    
    return $store;
}

sub get_store_from_pool {
    
    my $self  = shift;
    my $pool  = shift;
    my $node  = shift;
    
    my $pkg = $self->_get_pkg_name;
    
    if ($node) {
        return $pool->get($node);    
    }
    
    die 'use select() to switch/choose from pool' unless defined $__pool->{$pkg};
    return $pool->get( $__pool->{$pkg} );
    
}

sub select {
    
    my $self = shift;
    my $node = shift;
    
    if ( $self eq __PACKAGE__ ) {
        Gideon::Error->throw('use select() from your class');
    }
    
    my $id   = $self->_store_info;
    my $pool = $stores{$id};
    my $pkg  = $self->_get_pkg_name;

    unless ( ref($pool) eq 'Gideon::Connection::Pool' ) {
        Gideon::Error->throw('not a valid pool class defined');
    }
    unless ($pool->detect($node)) {
        Gideon::Error->throw('invalid identifier ' .$node . ' is not in the pool');
    }
    
    $__pool->{$pkg} = $node;
    return 1;
    
}

sub store($) {
    my $store = shift || return undef;
    my $caller = caller;
    $__store->{$caller} = $store;
}

sub check_meta {

    my $class     = shift;
    my $pkg       = $class->_get_pkg_name;
    my $meta      = $__meta->{$pkg} || $class->get_all_meta;
    my $attribute = shift;

    unless ( exists $meta->{attributes}->{$attribute} ) {
        Gideon::Error->throw('invalid meta data \'' . $attribute . '\' for class ' . $pkg);
    }

    return $meta->{attributes}->{$attribute};

}

sub get_serial_attr {
    my $class = shift;
    if (my $serials = $class->get_serial_attr_hash) {
        my $attr;
        foreach (sort keys %{ $serials }) {
            $attr = $_;
            last;
        }
        return $attr;
    }
}

sub get_serial_attr_hash {

    my $class = shift;
    my $pkg   = $class->_get_pkg_name;
    my $meta  = $__meta->{$pkg} || $class->get_all_meta;
    my $hash  = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        next unless defined $meta->{attributes}->{$attribute}->{serial};
        $hash->{$attribute} = $attribute;
    }

    return scalar keys %{$hash} == 1 ? $hash : undef;
    
}

sub get_serial_columns_hash {

    my $class = shift;
    my $pkg   = $class->_get_pkg_name;
    my $meta  = $__meta->{$pkg} || $class->get_all_meta;
    my $hash  = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        next unless defined $meta->{attributes}->{$attribute}->{serial};
        $hash->{$attribute} = $class->get_colum_for_attribute($attribute);
    }

    return scalar keys %{$hash} == 1 ? $hash : undef;
}

sub get_columns_hash {

    my $class   = shift;
    my $options = shift || '';
    my $pkg     = $class->_get_pkg_name;
    my $meta    = $__meta->{$pkg} || $class->get_all_meta;
    my $hash    = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( $options =~ /filter_keys/ ) {
            next unless defined $meta->{attributes}->{$attribute}->{key};
        }
        $hash->{$attribute} = $class->get_colum_for_attribute($attribute);
    }

    return $hash;
}

sub get_key_columns_hash {
    my $class = shift;
    return $class->get_columns_hash('filter_keys');
}

sub get_attributes_from_meta {

    my $class = shift;
    my $pkg   = $class->_get_pkg_name;
    my $meta  = $__meta->{$pkg} || $class->get_all_meta;

    my @map = map { $_ } ( keys %{ $meta->{attributes} } );
    return \@map;
}

sub get_attribute_for_column {

    my $class  = shift;
    my $column = shift;
    my $pkg    = $class->_get_pkg_name;
    my $meta   = $__meta->{$pkg} || $class->get_all_meta;

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( $column and $class->get_colum_for_attribute($attribute) eq $column ) {
            return $attribute;
        }
    }

    return undef;
}

sub map_args_with_meta {

    my $class = shift;
    my $args  = shift;
    my $meta  = $__meta || {};
    my $map   = {};
    my $pkg   = $class->_get_pkg_name;

    foreach my $arg ( keys %{$args} ) {
        
        if ( my $col = $class->get_colum_for_attribute($arg)) {
            $map->{$col} = $arg;
            next
        }
        
        Gideon::Error->throw('invalid argument ' . $arg . ' for ' . $pkg);
        
    }

    return $map;

}

sub get_colum_for_attribute {

    my $class     = shift;
    my $attribute = shift;
    my $meta      = $__meta->{$class} || $class->get_all_meta;

    if ( exists $meta->{attributes}->{$attribute}->{column} ) {
        return $meta->{attributes}->{$attribute}->{column};
    }
    return;
}

sub get_all_meta {

    my $class = shift;

    my $meta       = $class->meta;
    my $cache_meta = {};

    for my $attribute (
        map { $meta->get_attribute($_) }
        sort $meta->get_attribute_list
      ) {

        my $name = $attribute->name;
        if ( ref($attribute) =~ /Moose::Meta::Attribute/ ) {
            next;
        }

        $cache_meta->{$class}->{attributes}->{$name}->{key}    = $attribute->primary_key;
        $cache_meta->{$class}->{attributes}->{$name}->{column} = $attribute->column if ( $attribute->can('column') );
        $cache_meta->{$class}->{attributes}->{$name}->{serial} = $attribute->serial if ( $attribute->can('serial') );
    }

    $__meta = $cache_meta;

    return $cache_meta->{$class};
}

sub get_columns_from_meta {

    my $class = shift;

    my $meta = $__meta->{$class} || $class->get_all_meta;
    my @columns = ();

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( exists $meta->{attributes}->{$attribute}->{column} ) {
            push @columns, $meta->{attributes}->{$attribute}->{column};
        }
    }

    return wantarray ? @columns : \@columns;

}

sub store_registered {
    my $class      = shift;
    my $store_name = shift;
    my @args       = @_;

    if ( exists $__stricts->{$store_name} ) {
        die 'store \''. $store_name .'\' is already registered' if exists $stores{$store_name};        
    }
    return;
}

sub cache_registered {
    my $class = shift;
    return ($__cache) ? 1 : 0;
}

sub signature_for_cache {
    my $class = shift;
    my $pkg  = $class->_get_pkg_name;
    my $id = $pkg . '_' . $class->get_store_id;
    return $id;
}

sub get_cache_module {
    my $class = shift;
    if ($class->cache_registered) {
        return $__cache
    }
    return;
}

# Imports ----------------------------------------------------------------------

no strict 'refs';
no warnings 'redefine';

sub import {

    my ($class) = @_;
    my $caller = caller;

    *{"${caller}::store"} = \&store;

}

use strict 'refs';
use warnings 'redefine';

# Private ----------------------------------------------------------------------

sub _init {

    my $self = shift;
    my $args = shift;
    return;
}

sub _transform_sort_by_from_array {

    my $class     = shift;
    my $config    = shift;
    my $options   = shift;
    my $flattened = [];

    foreach my $clause ( @{$config} ) {
        if ( ref($clause) eq 'HASH' ) {
            my $flat = $class->_transform_sort_by_from_hash( $clause, $options );
            push @{$flattened}, $flat;
        } else {
            $class->check_meta($clause) unless $options =~ /skip_meta_check/;
            push @{$flattened}, $class->get_colum_for_attribute($clause);
        }
    }

    return $flattened;

}

sub _transform_sort_by_from_hash {

    my $class   = shift;
    my $config  = shift;
    my $options = shift;

    my $flattened = [];

    foreach my $clause ( keys %{$config} ) {

        my $direction = '';

        if ( $clause eq 'desc' ) {
            $direction = '-desc';
        }
        if ( $clause eq 'asc' ) {
            $direction = '-asc';
        }

        if ( ref( $config->{$clause} ) eq 'ARRAY' ) {

            my $columns = [];

            foreach ( @{ $config->{$clause} } ) {
                my $attr = $_;
                $class->check_meta($attr) unless $options =~ /skip_meta_check/;
                my $column = $class->get_colum_for_attribute($attr);
                push @{$columns}, $column;
            }

            push @{$flattened}, { $direction => $columns };

        } else {

            my $attr = $config->{$clause};
            $class->check_meta($attr) unless $options =~ /skip_meta_check/;
            my $column = $class->get_colum_for_attribute($attr);
            push @{$flattened}, { $direction => $column };

        }
    }

    return $flattened;

}

sub _transform_filter {

    my $class   = shift;
    my $filter  = shift;
    my @filters = @_;

    my %map = (
        'like' => '-like',
        'eq'   => '=',
        'gt'   => '>',
        'lt'   => '<',
        'not'  => '!',
        'gte'  => '>=',
        'lte'  => '<=',
    );

    foreach my $filter_type ( keys %{$filter} ) {
        if (   $filter_type eq 'like'
            or $filter_type eq 'gt'
            or $filter_type eq 'eq'
            or $filter_type eq 'lt'
            or $filter_type eq 'not'
            or $filter_type eq 'gte'
            or $filter_type = 'lte' ) {

            push @filters, { $map{$filter_type} => $class->transform_filter_values( $filter_type, $filter->{$filter_type} ) };

        } else {
            Gideon::Error->throw( $filter_type . ' is not a valid filter' );
        }
    }

    return @filters;
}

sub _get_pkg_name {
    my $self  = shift;
    my $pkg   = ref($self) ? ref($self) : $self;
    return $pkg;    
}

sub _store_info {
    my $self = shift;
    my ( $id, $dest ) = split( /:/, $__store->{$self->_get_pkg_name} );
    return wantarray ? ( $id, $dest ) : $id; 
}

1;

__END__

=head1 AUTHOR

Gines Razanov

=head1 COPYRIGHT

The following copyright notice applies to all the files provided in
this distribution, including binary files, unless explicitly noted
otherwise.

Copyright 2011 Gines Razanov

=head1 CONTRIBUTORS

Mariano Wahlmann (bluescreen10)

=head1 SEE ALSO

GitHub: L<https://github.com/ginesr/Gideon>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
