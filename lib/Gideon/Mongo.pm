
package Gideon::Mongo;

use strict;
use warnings;
use Gideon::Error;
use Gideon::Error::Simple;
use MongoDB;
use Try::Tiny;
use Carp qw(cluck croak);
use Data::Dumper qw(Dumper);
use Gideon::Results;
use Mouse;
use Set::Array;

our $VERSION = '0.02';

extends 'Gideon';
has '_mongo_id' => ( is => 'rw', isa => 'MongoDB::OID' );

sub remove { }

sub save {

    my $self = shift;

    unless ( ref($self) ) {
        Gideon::Error->throw('save() is not a static method');
    }

    return undef if ( $self->is_stored and not $self->is_modified );

    try {

        my $table  = $self->get_store_destination();
        my $obj    = $self->mongo_conn($table);
        my $fields = $self->get_attributes_from_meta();

        unless ( $self->is_stored ) {
            # remove auto increment columns for insert
            $fields = $self->remove_auto_columns_for_insert($fields);
        }

        my %map = map { $_, $self->$_ } @{$fields};
        
        if ( $self->is_stored ) {
            
            if (!$self->_mongo_id) {
                Gideon::Error::Simple->throw('Can\'t update record without object ID');
            }
            
        }
        else {
            
            if ( my $serial = $self->get_serial_attr() ) {
                my $next_id = $self->increment_serial($table);
                $map{$serial} = $next_id;
            }
            
            my $id = $obj->insert( \%map );
            $self->_mongo_id($id);
        }
        
        return;

    }
    catch {
        cluck $_;
        croak $_;
    }

}

sub increment_serial {
    
    my $self = shift;
    my $table = shift || die;
    
    my $serial_data = $self->mongo_conn('gideon_serial');
    my $data        = $serial_data->find( { 'table' => $table } )->next;
    
    if ($data) {
        my $id = $data->{id} + 1;
        $serial_data->update( { "_id" => $data->{_id} }, { '$set' => { 'id' => $id } } );
        return $id;
    }

    my $id = $serial_data->insert( {'table' => $table, 'id' => 1 } );
    return 1;
    
}

sub find { }

sub find_all {

    my $class = shift;

    try {

        my $obj     = $class->mongo_conn( $class->get_store_destination() );
        my $results = Set::Array->new;
        my $all     = $obj->find;

        while ( my $doc = $all->next ) {

            my $mongo_id = $doc->{_id};

            my @construct_args = map { $_, $doc->{$_} } keys %{$doc};
            my $obj = $class->new(@construct_args);
            $obj->is_stored(1);
            $obj->_mongo_id($mongo_id);

            $results->push($obj);
        }

        return $results;

    }
    catch {
        cluck $_;
        return $_;
    };
}

sub mongo_conn {

    my $class   = shift;
    my $table   = shift;
    my $db      = $class->get_store_id();
    my $db_conn = $class->_from_store_conn()->$db;

    if ($table) {
        return $db_conn->$table;
    }

    return $db_conn;

}

sub lt {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub gt {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub gte {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub lte {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub remove_auto_columns_for_insert {

    my $self  = shift;
    my $field = shift;

    my $serial = $self->get_serial_columns_hash;
    my $filter = [];

    foreach ( @{$field} ) {
        unless ( exists $serial->{$_} ) {
            push @{$filter}, $_;
        }
    }
    $field = $filter;
    return $field;

}

# Private ----------------------------------------------------------------------

sub _from_store_conn {

    my $class = shift;
    my $store = $class->get_store_args();

    if ( ref($store) eq 'MongoDB::Connection' ) {
        return $store;
    }

    if ( ref($store) and $store->can('connect') ) {
        return $store->connect();
    }

    return $store;

}

1;
