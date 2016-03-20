
=head1 NAME

Gideon - Datamapper written in Perl

=head1 DESCRIPTION

Gideon is intended to be an ORM completly written in Perl

=cut

package Gideon;

use Moose;
use warnings;
use 5.008_001;
use Exporter qw(import);
use Data::Dumper qw(Dumper);
use Carp qw(cluck);
use Scalar::Util qw(blessed looks_like_number);
use Gideon::Error;
use JSON::XS;
use Gideon::Meta;
use MooseX::ClassAttribute;
use Gideon::Store;
use Gideon::Cache;
use Gideon::Params;

our $VERSION = '0.03';
$VERSION = eval $VERSION;

our $EXCEPTION_DEBUG = 0;

use overload
    '""' => \&as_string,
    fallback => 1;

has 'is_modified' => ( is => 'rw', isa => 'Bool', default => 0);
has 'is_stored' => ( is => 'rw', isa => 'Bool', default => 0, lazy => 1 );

class_has 'metadata' => ( is => 'rw', isa => 'Gideon::Meta', lazy => 1, default => sub { my $self = shift; Gideon::Meta->new } );
class_has 'storage' => ( is => 'rw', isa => 'Gideon::Store', lazy => 1, default => sub { my $self = shift; Gideon::Store->new } );
class_has 'cache' => ( is => 'rw', isa => 'Gideon::Cache', lazy => 1, default => sub { my $self = shift; Gideon::Cache->new } );
class_has 'params' => ( is => 'rw', isa => 'Gideon::Params', lazy => 1, default => sub { my $self = shift; Gideon::Params->new } );

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

    die 'register_cache() is a class method' if blessed $class;
    die 'invalid class name' if ($module eq __PACKAGE__ or $module eq 'Gideon::Cache');

    return $class->cache->register($module)

}

# overload in subclass if applicable--------------------------------------------

sub find {}
sub find_all {}
sub save {}
sub remove {}
sub update {}
sub remove_all {}
sub update_all {}

# ------------------------------------------------------------------------------

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

sub in {
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

sub stores_for_foreign {}
sub columns_meta_for_foreign {}

sub as_hash {
    my $self = shift;
    return { map { $_ => $self->$_ } keys %{ $self->metadata->get_columns_hash } };
}

sub as_string {

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

# Params------------------------------------------------------------------------

before 'params' => sub {
    my $self = shift;
    Gideon::Params->who($self->_get_pkg_name);
};

# Cache ------------------------------------------------------------------------

before 'cache' => sub {
    my $self = shift;
    Gideon::Cache->who($self->_get_pkg_name);
};

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

}

use strict 'refs';
use warnings 'redefine';

# Private ----------------------------------------------------------------------

sub _get_pkg_name {
    my $class = shift;
    return ref($class) ? ref($class) : $class;
}

__PACKAGE__->meta->make_immutable();
no Moose;
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
