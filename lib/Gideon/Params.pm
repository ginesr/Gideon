package Gideon::Params;

use Moose;
use Gideon::Error;
use Data::Dumper qw(Dumper);
use MooseX::ClassAttribute;
use Hash::MultiValue;

class_has 'who' => ( is => 'rw', isa => 'Str' );

sub decode {

    my $class  = shift;
    my @args   = @_;
    my $args   = {};
    my $config = {};

    # check if there are options passed, last argument as hashref
    if ( $class->check_for_config(@args) ) {
        $config = pop @args;
        if ( exists $config->{order_by} ) {
            $config->{order_by} = $class->validate_sorting( $config->{order_by} );
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

sub normalize {

    my $class   = shift;
    my $args    = shift;
    my $options = shift || '';

    foreach my $attribute ( keys %{$args} ) {
        if ($attribute eq '-or' and ref $args->{$attribute} eq 'HASH' ) {
            my @attributes = ();
            push @attributes, map { $_ } keys %{ $args->{$attribute} };
            foreach (@attributes) {
                $class->who->metadata->check_meta($_);
                my $value_filtered = $class->transform_filters( $args->{$attribute}->{$_} );
                $args->{$attribute}->{$_} = $value_filtered
            }
        }
        else {
            $class->who->metadata->check_meta($attribute) unless $options =~ /skip_meta_check/;
            my $value_filtered = $class->transform_filters( $args->{$attribute} );
            $args->{$attribute} = $value_filtered
        }
    }

    return $args;

}

sub check_for_config {
    
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

sub validate_sorting {

    my $class   = shift;
    my $config  = shift;
    my $options = shift || '';

    if ( ref($config) eq 'ARRAY' ) {
        $config = $class->_sorting_from_array( $config, $options );
    }
    if ( ref($config) eq 'HASH' ) {
        $config = $class->_sorting_from_hash( $config, $options );
    }
    unless ( ref($config) ) {
        $class->who->metadata->check_meta($config) unless $options =~ /skip_meta_check/;
        $config = $class->who->metadata->get_column_for_attribute($config);
    }

    return $config;

}

sub transform_filters {

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
            my @filters = $class->_tranform_operator( $_, @filters );
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
        @filters = $class->_tranform_operator( $filter, @filters );
    }

    return scalar @filters == 1 ? $filters[0] : \@filters;

}

# Private ----------------------------------------------------------------------

sub _sorting_from_array {

    my $class     = shift;
    my $config    = shift;
    my $options   = shift;
    my $flattened = [];

    foreach my $clause ( @{$config} ) {
        if ( ref($clause) eq 'HASH' ) {
            my $flat = $class->_sorting_from_hash( $clause, $options );
            push @{$flattened}, $flat;
        } else {
            $class->who->metadata->check_meta($clause) unless $options =~ /skip_meta_check/;
            push @{$flattened}, $class->who->metadata->get_column_for_attribute($clause);
        }
    }

    return $flattened;

}

sub _sorting_from_hash {

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
                $class->who->metadata->check_meta($attr) unless $options =~ /skip_meta_check/;
                my $column = $class->who->metadata->get_column_for_attribute($attr);
                push @{$columns}, $column;
            }

            push @{$flattened}, { $direction => $columns };

        } else {

            my $attr = $config->{$clause};
            $class->who->metadata->check_meta($attr) unless $options =~ /skip_meta_check/;
            my $column = $class->who->metadata->get_column_for_attribute($attr);
            push @{$flattened}, { $direction => $column };

        }
    }

    return $flattened;

}

sub _tranform_operator {

    my $class   = shift;
    my $filter  = shift;
    my @filters = @_;

    my %operator_map = (
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
                
            $hash->{ $operator_map{$filter_type} } = $class->_values_thru_filter( $filter_type, $filter->{$filter_type} );

        } else {
            Gideon::Error->throw( $filter_type . ' is not a valid filter' );
        }
    }
    push @filters, $hash;
    return @filters;
}

# this will call $class->eq($string), $class->like($string), an so on ...

sub _values_thru_filter {

    my $class  = shift;
    my $type   = shift;
    my $values = shift;

    my @values = ();

    if ( ref $values eq 'ARRAY' ) {
        foreach my $filter_value ( @{$values} ) {
            push @values, $class->who->$type($filter_value);
        }
    } else {
        push @values, $class->who->$type($values);
    }

    return scalar @values == 1 ? $values[0] : \@values;
}

__PACKAGE__->meta->make_immutable();