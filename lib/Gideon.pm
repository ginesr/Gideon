
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
my $__store = '';

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

sub create {
    my $class = shift;
    my @args  = @_;
    my $self  = {@args};
    bless $self, $class;
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

sub decode_params {

    my $class  = shift;
    my @args   = @_;
    my $config = {};

    if ( ref( $args[-1] ) eq 'HASH' ) {
        $config = pop @args;
    }

    return {@args}, $config;

}

sub trans_filters {

    my $class  = shift;
    my $filter = shift;

    unless ( ref($filter) ) {
        return $filter;
    }
    if ( ref($filter) eq 'HASH' ) {

        my $filter_type = ( map { $_ } keys %{$filter} )[0];

        if ( $filter_type eq 'like' or $filter_type eq 'gt' or $filter_type eq 'lt' or $filter_type eq 'not' ) {
            return $class->$filter_type( $filter->{$filter_type} );
        } else {
            Gideon::Error->throw( $filter_type . ' is not a valid filter' );
        }
    }

}

sub get_store_destination {
    my $self  = shift;
    my $store = $__store;
    my ( $id, $dest ) = split( /:/, $store );
    die 'invalid store' unless $stores{$id};
    return $dest;
}

sub get_store_args {
    my $self  = shift;
    my $store = $__store;
    my ( $id, $table ) = split( /:/, $store );
    die 'invalid store' unless $stores{$id};
    return $stores{$id};
}

sub store($) {
    my $store = shift || return undef;
    $__store = $store;
    my ( $id, $table ) = split( /:/, $store );
}

sub check_meta {

    my $class     = shift;
    my $meta      = $__meta || $class->get_all_meta;
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

sub get_columns_hash {
    my $class  = shift;
    my $meta   = $__meta || $class->get_all_meta;
    my $hash   = {};
    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        $hash->{$attribute} = $class->get_colum_for_attribute($attribute);
    }
    return $hash;
}

sub get_key_columns_hash {
    my $class  = shift;
    my $meta   = $__meta || $class->get_all_meta;
    my $hash   = {};
    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        next unless defined $meta->{attributes}->{$attribute}->{key};
        $hash->{$attribute} = $class->get_colum_for_attribute($attribute);
    }
    return $hash;
}

sub get_attribute_for_column {

    my $class  = shift;
    my $column = shift;
    my $meta   = $__meta || {};

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

sub get_table_from_meta {

    my $class = shift;
    my $meta = $__meta || {};

    return $meta->{table};
}

sub get_colum_for_attribute {

    my $class     = shift;
    my $attribute = shift;
    my $meta      = $__meta || {};

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
        my $col = $attribute->column;
        my $key = $attribute->primary_key;
        
        $cache_meta->{attributes}->{$name}->{column} = $col;
        $cache_meta->{attributes}->{$name}->{key} = $key;
    }

    $__meta = $cache_meta;
}

sub get_columns_from_meta {

    my $class   = shift;
    my $meta    = $__meta || $class->get_all_meta;
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
