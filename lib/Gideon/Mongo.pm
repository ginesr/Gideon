
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

        my $db    = $class->get_store_id();
        my $table = $class->get_store_destination();

        my $db_conn = $class->from_store_conn()->$db;
        my $obj     = $db_conn->$table;

        my $results = Set::Array->new;
        my $all     = $obj->find;

        while ( my $doc = $all->next ) {
            my $mongo_id = $doc->{_id};

            my @construct_args = map { $_, $doc->{$_} } keys %{ $doc };
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

sub from_store_conn {

    my $class = shift;
    my $store = $class->get_store_args();
    return $store->[0];

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

1;
