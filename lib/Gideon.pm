
package Gideon;

use strict;
use warnings;
use Exporter qw(import);
use Data::Dumper qw(Dumper);
use Carp qw(cluck);
use Gideon::Error;
use Mouse;

our $VERSION = '0.02';

my $__meta  = undef;
my $__store = {};

our %stores = ();

after 'new' => sub {

    my $self = shift;
    my $meta = $self->meta;

    for my $attribute (
        map { $meta->get_attribute($_) }
        sort $meta->get_attribute_list
      ) {

        my $name = $attribute->name;

        $meta->add_before_method_modifier(
            $name,
            sub {
                my $self      = shift;
                my $new_value = shift;
                if ( defined $new_value ) {
                    my $meta      = $self->meta;
                    my $attribute = $meta->get_attribute($name);
                    my $reader    = $attribute->get_read_method;
                    my $value     = $self->$reader;
                    if ( defined $value and $value ne $new_value ) {
                        $self->is_modified(1);
                    }
                }
            }
        );
    }
    $meta->add_attribute(
        'is_modified' => (
            is      => 'rw',
            isa     => 'Bool',
            default => 0,
        )
    );
    $meta->add_attribute(
        'is_stored' => (
            is      => 'rw',
            isa     => 'Bool',
            default => 0,
            lazy    => 1,
        )
    );

};

sub register_store {
    my $class      = shift;
    my $store_name = shift;
    my @args       = @_;
    die if ref $class;
    $stores{$store_name} = \@args;
}

sub new {

    my $class = shift;
    my @args  = @_;
    my $self  = {@args};
    bless $self, $class;
    $self->_init(@args);
    return $self;

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

sub filter_rules {

    my $class = shift;
    my $args  = shift;

    foreach ( keys %{$args} ) {
        $class->check_meta($_);
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

sub decode_params {

    my $class  = shift;
    my @args   = @_;
    my $config = {};
    if ( ( scalar(@args) % 2 ) != 0 and ref( $args[-1] ) eq 'HASH' ) {
        $config = pop @args;
    }

    return {@args}, $config;

}

sub trans_filters {

    my $class  = shift;
    my $filter = shift;

    my @filters = ();
    my %map     = (
        'like' => '-like',
        'gt'   => '>',
        'lt'   => '<',
        'not'  => '!',
        'gte'  => '>=',
        'lte'  => '<=',
    );

    unless ( ref($filter) ) {
        return $filter;
    }
    
    if ( ref($filter) eq 'HASH' ) {

        foreach my $filter_type ( keys %{$filter} ) {
            if (   $filter_type eq 'like'
                or $filter_type eq 'gt'
                or $filter_type eq 'lt'
                or $filter_type eq 'not'
                or $filter_type eq 'gte'
                or $filter_type = 'lte' ) {

                push @filters, { $map{$filter_type} => $class->transform_filter_values( $filter_type, $filter->{$filter_type} ) };

            } else {
                Gideon::Error->throw( $filter_type . ' is not a valid filter' );
            }
        }

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

sub get_store_destination {
    my $self  = shift;
    my $pkg   = ref($self) ? ref($self) : $self;
    my $store = $__store->{$pkg};
    my ( $id, $dest ) = split( /:/, $store );
    die 'invalid store, did you define ' . $id . '?' unless $stores{$id};
    return $dest;
}

sub get_store_args {
    my $self  = shift;
    my $pkg   = ref($self) ? ref($self) : $self;
    my $store = $__store->{$pkg};
    my ( $id, $table ) = split( /:/, $store );
    die 'invalid store' unless $stores{$id};
    return $stores{$id};
}

sub store($) {
    my $store = shift || return undef;
    my $caller = caller;
    $__store->{$caller} = $store;
}

sub check_meta {

    my $class     = shift;
    my $pkg       = ref($class) ? ref($class) : $class;
    my $meta      = $__meta->{$pkg} || $class->get_all_meta;
    my $attribute = shift;

    unless ( exists $meta->{attributes}->{$attribute} ) {
        Gideon::Error->throw('invalid meta data');
    }

    return $meta->{attributes}->{$attribute};

}

sub map_meta_with_row {

    my $class = shift;
    my $row   = shift;

    my $map = {};

    foreach my $r ( keys %{$row} ) {
        my $attribute = $class->get_attribute_for_column($r);
        $map->{$attribute} = $r;
    }

    return $map;

}

sub get_serial_columns_hash {

    my $class = shift;
    my $pkg   = ref($class) ? ref($class) : $class;
    my $meta  = $__meta->{$pkg} || $class->get_all_meta;
    my $hash  = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        next unless defined $meta->{attributes}->{$attribute}->{serial};
        $hash->{$attribute} = $class->get_colum_for_attribute($attribute);
    }
    return scalar keys %{$hash} == 1 ? $hash : undef;
}

sub get_columns_hash {

    my $class      = shift;
    my $filter_key = shift || 0;
    my $pkg        = ref($class) ? ref($class) : $class;
    my $meta       = $__meta->{$pkg} || $class->get_all_meta;
    my $hash       = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ($filter_key) {
            next unless defined $meta->{attributes}->{$attribute}->{key};
        }
        $hash->{$attribute} = $class->get_colum_for_attribute($attribute);
    }
    return $hash;
}

sub get_key_columns_hash {
    my $class = shift;
    return $class->get_columns_hash(1);
}

sub get_attribute_for_column {

    my $class  = shift;
    my $column = shift;
    my $pkg    = ref($class) ? ref($class) : $class;
    my $meta   = $__meta->{$pkg} || $class->get_all_meta;

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( $class->get_colum_for_attribute($attribute) eq $column ) {
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

    foreach my $arg ( keys %{$args} ) {
        my $col = $class->get_colum_for_attribute($arg);
        $map->{$col} = $arg;
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
    return undef;
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
        next unless $attribute->isa('Gideon::Meta::Attribute::DBI');

        $cache_meta->{$class}->{attributes}->{$name}->{column} = $attribute->column;
        $cache_meta->{$class}->{attributes}->{$name}->{key}    = $attribute->primary_key;
        $cache_meta->{$class}->{attributes}->{$name}->{serial} = $attribute->serial;
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
    my $args = {@_};

}

1;
