
package Gideon;

use strict;
use warnings;
use Exporter qw(import);
use Data::Dumper qw(Dumper);
use Carp qw(cluck);
use Gideon::Error;

my $__meta = {};

our @EXPORT = ('meta');

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

sub insert {
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

sub meta {

    my $meta = shift || return undef;

    $__meta = $meta;

    foreach my $attr ( keys %{ $meta->{attributes} } ) {
        __PACKAGE__->add_accessor($attr);
    }

}

sub check_meta {

    my $class     = shift;
    my $meta      = $__meta || {};
    my $attribute = shift;

    if ( exists $meta->{attributes}->{$attribute} ) {
        if ( exists $meta->{attributes}->{$attribute}->{isa} ) {

            #check class type
        }
    } else {
        Gideon::Error->throw('invalid meta data');
    }

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

sub get_columns_from_meta {

    my $class = shift;

    my $meta = $__meta || {};
    my @columns = ();

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( exists $meta->{attributes}->{$attribute}->{column} ) {
            push @columns, $meta->{attributes}->{$attribute}->{column};
        }
    }

    return wantarray ? @columns : \@columns;

}

sub is_dirty {
    
    my $self  = shift;
    return $self->{dirty_flag};
    
}

sub set {
    my $self  = shift;
    my $field = shift;

    if ( @_ == 1 ) {
        $self->{$field} = $_[0];
    } elsif ( @_ > 1 ) {
        $self->{$field} = [@_];
    } else {
        die "Wrong number of arguments received";
    }
    $self->{dirty_flag} ++;
}

sub get {
    my $self = shift;
    if ( @_ == 1 ) {
        return $self->{ $_[0] };
    } elsif ( @_ > 1 ) {
        return @{$self}{@_};
    } else {
        die "Wrong number of arguments received";
    }
}

no strict 'refs';
no warnings 'redefine';

sub add_accessor {
    my ( $class, $field ) = @_;

    my $fullname = "${class}::$field";

    *{$fullname} = sub {
        my $self = shift;

        if (@_) {
            return $self->set( $field, @_ );
        } else {
            return $self->get($field);
        }
    };
}

sub import {

    my ($class) = @_;
    my $caller = caller;

    *{"${caller}::meta"} = \&meta;

}

use strict 'refs';
use warnings 'redefine';

# Private ----------------------------------------------------------------------

sub _init {

    my $self = shift;
    my $args = {@_};

    if ( exists $self->{dbh} ) {
        $self->__dbh( $self->{dbh} );
    }
    
    $self->{dirty_flag} = 0;

    $self->_check_required();
    $self->_init_defaults();
}

sub _check_required {

    my $self = shift;
    my $meta = $__meta;

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( exists $meta->{attributes}->{$attribute}->{required} and $meta->{attributes}->{$attribute}->{required} == 1 ) {
            my $value = $self->$attribute();
            unless ($value) {
                Gideon::Error->throw( $attribute . ' is required' );
            }
        }
    }
}

sub _init_defaults {

    my $self = shift;
    my $meta = $__meta;

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( exists $meta->{attributes}->{$attribute}->{default} ) {
            unless ( defined $self->$attribute ) {
                my $default = $meta->{attributes}->{$attribute}->{default};
                $self->$attribute($default);
                $self->{dirty_flag} = 0;
            }
        }
    }
}

1;
