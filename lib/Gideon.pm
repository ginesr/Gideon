
=head1 NAME

Gideon - Datamapper written in Perl

=head1 DESCRIPTION

Gideon is intended to be an ORM completly written in Perl

=cut 

package Gideon;

use Moose;
use warnings;
use Exporter qw(import);
use Module::Load qw(load);
use Data::Dumper qw(Dumper);
use Carp qw(cluck);
use Scalar::Util qw(blessed looks_like_number);
use Gideon::Error;
use Hash::MultiValue;
use 5.008_001;
use JSON::XS;
use Gideon::Meta;
use MooseX::ClassAttribute;
use Gideon::Store;

our $VERSION = '0.03';
$VERSION = eval $VERSION;

our $EXCEPTION_DEBUG = 0;

use constant CACHE_DEFAULT_TTL => 300; # default expire seconds

my $__relations = {};
my $__cache = undef;
our $__obj_cache = 1;
our $_cache_ttl = undef;

use overload
    '""' => \&strigify,
    fallback => 1;

has 'is_modified' => ( is => 'rw', isa => 'Bool', default => 0);
has 'is_stored' => ( is => 'rw', isa => 'Bool', default => 0, lazy => 1 );

class_has 'metadata' => ( is => 'rw', isa => 'Gideon::Meta', lazy => 1, default => sub { my $self = shift; Gideon::Meta->new } );
class_has 'storage' => ( is => 'rw', isa => 'Gideon::Store', lazy => 1, default => sub { my $self = shift; Gideon::Store->new } );

sub BUILD {

    my $self = shift;
    my @args  = @_;

    $self->_init(@args);

}

sub register_store {

    my $class = shift;
    my $name = shift;
    my @args = @_;

    die 'register_store() is a class method' if blessed $class;
    die 'do not call register_store() from your own class, use Gideon->register_store(...)' if $class ne __PACKAGE__;

    my $strict = ( grep { /strict/ } @args ) ? 1 : 0;

    return $class->storage->register(
        name => $name,
        args => $args[0],
        strict => $strict
    )

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

sub update {
    my $class = shift;
    # overload in subclass
}

sub remove_all {
    my $class = shift;
    # overload in subclass    
}

sub update_all {
    my $class = shift;
    # overload in subclass    
}

sub disable_cache {
    $__obj_cache = 0;
}

sub enable_cache {
    $__obj_cache = 1;
}

sub set_cache_ttl {
    my $self = shift;
    my $secs = shift || undef;
    $_cache_ttl = $secs;
}

sub cache_ttl {
    my $self = shift;
    if ($_cache_ttl) {
        return $_cache_ttl
    }
    return CACHE_DEFAULT_TTL
}

sub cache_lookup {
    
    my $self = shift;
    my $key = shift;
    return if $__obj_cache == 0;
    my $module = $self->get_cache_module;
    return $module->get($key);
    
}

sub cache_store {
    
    my $self = shift;
    my $key = shift;
    my $what = shift;
    my $class = shift;
    
    return if $__obj_cache == 0;
    my $secs = $self->cache_ttl;
    
    $class = $self->_get_pkg_name if not $class;
    
    my $module = $self->get_cache_module;
    return $module->set( $key, $what, $secs, $class);

}

sub cache_clear {
    my $self = shift;
    my $class = shift;
    return if $__obj_cache == 0;
    my $module = $self->get_cache_module;
    return $module->clear( $class );
    
}

sub filter_rules {

    my $class   = shift;
    my $args    = shift;
    my $options = shift || '';

    foreach my $attribute ( keys %{$args} ) {
        if ($attribute eq '-or' and ref $args->{$attribute} eq 'HASH' ) {
            my @attributes = ();
            push @attributes, map { $_ } keys %{ $args->{$attribute} };
            foreach (@attributes) {
                $class->metadata->check_meta($_);
                my $value_filtered = $class->trans_filters( $args->{$attribute}->{$_} );
                $args->{$attribute}->{$_} = $value_filtered
            }    
        }
        else {
            $class->metadata->check_meta($attribute) unless $options =~ /skip_meta_check/;
            my $value_filtered = $class->trans_filters( $args->{$attribute} );
            $args->{$attribute} = $value_filtered
        }
    }

    return $args;

}

sub stringify_fields {
    
    my $self = shift;
    my $fields = shift;
    my @fields = ();
    
    # when binding parameters try to stringify objects using to_string method
    # then fallback to whatever overload is defined
    # useful when undef is needed to convert object into string
    
    my @stringify = ('to_string');
    
    foreach my $f (sort keys %{$fields}) {
        my $str = $self->$f;
        if (ref($self->$f) and blessed($self->$f)) {
            my $yes_it_can;
            foreach (@stringify) {
                if ($self->$f->can($_)) {
                    $str = $self->$f->$_;
                    $yes_it_can = 1;
                    last;
                }
            }
            if (!$yes_it_can && looks_like_number($self->$f)) {
                $str = $self->$f->value->numify;
            }
            else {
                $str = $self->$f . '' unless $yes_it_can;
            }

        }
        push @fields, $fields->{$f} => $str
    }
    
    return @fields
}

sub like {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub nlike {
    my $class = shift;
    my $string = shift || "";
    return $string;
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

sub ne {
    my $class = shift;
    my $string = shift || "";
    return '!' . $string;
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
        $class->metadata->check_meta($config) unless $options =~ /skip_meta_check/;
        $config = $class->metadata->get_column_for_attribute($config);
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
            my @pairs = ();
            if ( !ref( $_ ) ) {
                push @multi, $_;
                next;
            }
            my @filters = $class->_transform_filter( $_, @filters );
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

sub stores_for_foreign {}
sub columns_meta_for_foreign {}

sub has_many($%) {
    my $foreign = shift || return undef;
    my $params = {@_};
    my $caller = caller;

    $__relations->{$caller}{foreign} = $foreign;
    load($foreign);
    load(Gideon::Extensions::Join);
    $__relations->{$caller}{params} = $params;

    die if not $params->{predicate};

    $caller->meta->add_method(
        $params->{predicate} => sub {
            return Gideon::Extensions::Join->join_with(@_)
        }
    )
}

sub get_relations {
    my $self = shift;
    my $pkg = $self->_get_pkg_name;
    return $__relations->{$pkg};
}

sub as_hash {
    my $self = shift;
    return { map { $_ => $self->$_ } keys %{ $self->metadata->get_columns_hash } };
}

sub cache_registered {
    my $class = shift;
    return ($__cache) ? 1 : 0;
}

sub signature_for_cache {
    my $class = shift;
    my $pkg = $class->_get_pkg_name;
    my $id = $pkg . '_' . $class->storage->id;
    return $id;
}

sub get_cache_module {
    my $class = shift;
    if ($class->cache_registered) {
        return $__cache
    }
    return;
}

sub strigify {

    my $self = shift;

    my @attrs = $self->metadata->get_attributes_from_meta;
    my $primary_keys = $self->metadata->get_primary_key_hash;
    my $primary_key;

    if ( $self->is_stored ) {
        foreach my $attr (keys %$primary_keys) {
            $primary_key = $self->$attr
        }
    }

    my $class = ref $self;
    my %params = ();

    foreach my $attr (@attrs) {
        if ($self->metadata->get_value_for_attribute_key($attr,'lazy')) {
            unless ( $self->is_stored ) {
                # do not trigger lazy attributes
                $params{$attr."[lazy]"} = undef;
                next;
            }
        }
        if ( blessed($self->$attr) ) {
            # convert objects to strings
            if ($self->$attr->can('to_string')) {
                $params{$attr} = $self->$attr->to_string
            }
            elsif ($self->$attr->can('stringify')) {
                $params{$attr} = $self->$attr->stringify
            }
            elsif ($self->$attr->can('as_string')) {
                $params{$attr} = $self->$attr->as_string
            }
            else {
                if (defined $self->$attr) {
                    $params{$attr} = $self->$attr . ''
                }
                else {
                    $params{$attr} = undef
                }
            }
        }
        else {
            $params{$attr} = $self->$attr
        }
    }

    my $pkg_name = $class;

    if ($primary_key) {
        $pkg_name = "$pkg_name ($primary_key)"
    }

    my $json = JSON::XS->new
        ->utf8(0)
        ->pretty(0)
        ->space_after
        ->allow_blessed(0)
        ->convert_blessed(0)
        ->encode(\%params);

    return $pkg_name . " " .  $json

}

sub clone {
    my $self = shift;

    if (not blessed($self)) {
        die "can't clone if not an object";
    }

    my @attrs = $self->metadata->get_attributes_from_meta;
    my $serial = $self->metadata->get_serial_attr_hash;

    if ( $self->is_stored ) {
        foreach my $attr (keys %$serial) {
            my @indexes = grep { $attrs[$_] eq $attr } 0..scalar $#attrs;
            splice(@attrs, $indexes[0], 1);
        }
    }
    
    my $class = ref $self;
    my %params = ();
    
    foreach my $attr (@attrs) {
        if (blessed($self->$attr)) {
            if ($self->can('clone')) {
                $params{$attr} = $self->$attr->clone
            }
        }
        else {
            if (defined $self->$attr) {
                $params{$attr} = $self->$attr
            }
        }
    }

    my $cloned = $class->new(%params);
    return $cloned;
}

# Stores -----------------------------------------------------------------------

before 'storage' => sub {
    my $self = shift;
    Gideon::Store->who($self->_get_pkg_name);
};

sub store($) {
    my $store = shift || return undef;
    __PACKAGE__->storage->add_package({ name => caller, store => $store });
}

sub transaction($) {
    my $class = shift;
    return __PACKAGE__->storage->transaction(shift)
}

# Metadata ---------------------------------------------------------------------

before 'metadata' => sub {
    my $self = shift;
    Gideon::Meta->who($self->_get_pkg_name);
};

# Imports ----------------------------------------------------------------------

no strict 'refs';
no warnings 'redefine';

sub import {

    my ($class) = @_;
    my $caller = caller;

    *{"${caller}::store"} = \&store;
    *{"${caller}::has_many"} = \&has_many;

}

use strict 'refs';
use warnings 'redefine';

# Private ----------------------------------------------------------------------

sub _init {

    my $self = shift;
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
            $class->metadata->check_meta($clause) unless $options =~ /skip_meta_check/;
            push @{$flattened}, $class->metadata->get_column_for_attribute($clause);
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
                $class->metadata->check_meta($attr) unless $options =~ /skip_meta_check/;
                my $column = $class->metadata->get_column_for_attribute($attr);
                push @{$columns}, $column;
            }

            push @{$flattened}, { $direction => $columns };

        } else {

            my $attr = $config->{$clause};
            $class->metadata->check_meta($attr) unless $options =~ /skip_meta_check/;
            my $column = $class->metadata->get_column_for_attribute($attr);
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
        'like'  => '-like',
        'nlike' => '-not_like',
        'eq'    => '=',
        'gt'    => '>',
        'lt'    => '<',
        'gte'   => '>=',
        'lte'   => '<=',
        'ne'    => '!=',
    );
    
    my $hash = {};

    foreach my $filter_type ( keys %{$filter} ) {
        if (   $filter_type eq 'like'
            or $filter_type eq 'gt'
            or $filter_type eq 'eq'
            or $filter_type eq 'lt'
            or $filter_type eq 'ne'
            or $filter_type eq 'gte'
            or $filter_type eq 'lte'
            or $filter_type eq 'nlike' ) {
                
            $hash->{ $map{$filter_type} } = $class->transform_filter_values( $filter_type, $filter->{$filter_type} );

        } else {
            Gideon::Error->throw( $filter_type . ' is not a valid filter' );
        }
    }
    push @filters, $hash;
    return @filters;
}

sub _get_pkg_name {
    my $class = shift;
    my $pkg  = ref($class) ? ref($class) : $class;
    return $pkg;    
}

__PACKAGE__->meta->make_immutable();

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
