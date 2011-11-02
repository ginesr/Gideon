
package Gideon::Mongo;

use strict;
use warnings;
use Gideon::Error;
use Gideon::Error::Simple;
use MongoDB;
use Try::Tiny;
use Carp qw(cluck);
use Data::Dumper qw(Dumper);
use Gideon::Results;
use Mouse;
use Set::Array;

our $VERSION = '0.02';

extends 'Gideon';
has '_mongo_id' => ( is => 'rw', isa => 'MongoDB::OID' );

sub remove { }
sub save   { }
sub find   { }

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

# Private ----------------------------------------------------------------------

sub _from_store_conn {

    my $class = shift;
    my $store = $class->get_store_args();

    if ( ref( $store ) eq 'MongoDB::Connection' ) {
        return $store;
    }

    if ( ref( $store ) and $store->can('connect') ) {
        return $store->connect();
    }

    return $store;

}

1;
