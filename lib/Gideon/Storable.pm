
package Gideon::Storable;

use strict;
use warnings;
use Gideon::Error;
use Gideon::Error::Simple;
use Gideon::Filters::Storable;
use Try::Tiny;
use Storable qw();
use Carp qw(cluck carp croak);
use Moose;
use Gideon::Storable::Results;

our $VERSION = '0.02';
my $cache = {};

extends 'Gideon';

sub save {

    my $self = shift;

    unless ( ref($self) ) {
        Gideon::Error->throw('save() is not a static method');
    }

    return undef if ( $self->is_stored and not $self->is_modified );

    try {

        my $fields = $self->metadata->get_columns_hash();

        unless ( $self->is_stored ) {

            # remove auto increment columns for insert
            # $self->remove_auto_columns_for_insert($fields);
        }

        my %data = map { $fields->{$_} => $self->$_ } sort keys %{$fields};

        if ( $self->is_stored ) {
        
        }
        else {
            
        }

        if ( my $serial = $self->metadata->get_serial_columns_hash ) {
            my $serial_attribute = ( map { $_ } keys %{$serial} )[0];
            my $last_id = $self->last_inserted_id;
            $self->$serial_attribute($last_id);
            $data{$serial_attribute} = $last_id;
        }
        
        my $hash = $self->storable_reference;
        $hash->{data}->{ $self->id } = \%data;
        $self->flush_to_disk($hash);
        
        $self->is_stored(1);
        $self->is_modified(0);

        return;

    }
    catch {
        my $e = shift;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak $e;
    }

}

sub like {
    my $class = shift;
    my $string = shift || "";
    return qr/$string/i;    
}

sub gt {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub lt {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub ne {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub lte {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub gte {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub find_all {
    
    my $class = shift;
    my ( $args, $config ) = $class->params->decode(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    try {
        
        $args = Gideon::Filters::Storable->format( $class->params->normalize($args) );
        
        my $results = Gideon::Storable::Results->new(package => $class);
        
        if ( my $found = $class->search_in_hash($args) ) {
            
            foreach my $result ( @{ $found } ) {
        
                my @construct_args = map { $_, $result->{$_} } keys %{$result};
                my $obj = $class->new(@construct_args);
                $obj->is_stored(1);
                
                $results->add_record($obj);
            
            }
        
        }
        
        return wantarray ? $results->records : $results;
        

    }
    catch {
        my $e = shift;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak $e;
    }
    
}
    
sub find {

    my $class = shift;
    my ( $args, $config ) = $class->params->decode(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    try {
        
        $args = Gideon::Filters::Storable->format( $class->params->normalize($args) );
        
        if ( my $found = $class->search_in_hash($args) ) {

            my @construct_args = map { $_, $found->[0]->{$_} } keys %{$found->[0]};
            my $obj = $class->new(@construct_args);
            $obj->is_stored(1);
                        
            return $obj;
        
        }
        
        return;

    }
    catch {
        my $e = shift;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak $e;
    }
    
}

sub search_in_hash {
    
    my $class = shift;
    my $args = shift;

    my $hash   = $class->storable_reference;
    my $data   = $hash->{data};
    my $found  = [];

    foreach my $rec ( sort { $a <=> $b } keys %{ $data } ) {
        if ( my $match = $class->test_filters( $data->{$rec}, $args ) ) {
            push @{ $found }, $data->{$rec};
        }
    }

    return $found;

}

sub test_filters {
    
    my $class = shift;
    my $rec = shift;
    my $filter = shift;
    
    foreach my $f ( keys %{ $filter } ) {
        
        my $value = $rec->{ $f };
        my $option = $filter->{ $f };
        
        if( !ref($option) ) {
            if ($value eq $option) {
                return 1;
            }
        }

        if (ref($option) and ref($option) eq 'Regexp') {
            if ($value =~ $option) {
                return 1;
            }
        }
        
        my $operand;
        my $compare;
        
        if (ref($option) and ref($option) eq 'HASH') {
            my @keys = keys %$option;
            $operand = $keys[0];
            $compare = $option->{$operand};
        }
        
        if (ref($option) and ref($option) eq 'ARRAY') {
            
            $operand = $option->[0];
            $compare = $option->[1];

        }
        
        if ($operand and $compare) {
            if ($operand eq '!') {
                if ($value ne $compare) {
                    return 1;
                }
            }
            if ($operand eq '!=') {
                if ($value ne $compare) {
                    return 1;
                }
            }
            if ($operand eq '>') {
                if ($value gt $compare) {
                    return 1;
                }
            }
            if ($operand eq '<') {
                if ($value lt $compare) {
                    return 1;
                }
            }
            if ($operand eq '>=') {
                if ($value >= $compare) {
                    return 1;
                }
            }
            if ($operand eq '<=') {
                if ($value <= $compare) {
                    return 1;
                }
            }            
        }
        
    }
    
    return;
    
}

sub last_inserted_id {
    
    my $self = shift;
    my $hash = $self->storable_reference;
    my $id_from_meta = $hash->{meta}->{last_id} + 1;
    
    $hash->{meta}->{last_id} = $id_from_meta;
    $self->flush_to_disk($hash);
    
    return $id_from_meta;
}

sub storable_reference {
    my $self = shift;
    return Storable::retrieve( $self->_from_store_ref );
}

sub flush_to_disk {
    my $self = shift;
    
    my $data = shift;
    
    $data->{meta}->{last_updated} = time();
    
    my $store = $self->_from_store_ref;
    Storable::store $data, $store;
    return 1;
}

sub _from_store_ref {

    my $self = shift;
    my $store = $self->storage->args();

    if ( ref( $store ) and $store->can('connect') ) {
        return $store->connect();
    }
    
    return $store;
    
}

__PACKAGE__->meta->make_immutable();
