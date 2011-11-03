#!/usr/bin/perl

use lib '.lib/';
use strict;
use Try::Tiny;
use Test::More;
use Data::Dumper qw(Dumper);

if ( mongo_not_installed() ) {
    plan skip_all => 'MongoDB module not installed';
}
elsif ( mongo_not_running() ) {
    plan skip_all => 'Mongo daemon not running on localhost';
} else {
    plan tests => 3;
}

use Example::Driver::Mongo;
use Mongo::Person;
use MongoDB;

# Prepare test data ------------------------------------------------------------

my $conn    = MongoDB::Connection->new;
my $db      = $conn->gideon;
my $persons = $db->person;

$persons->drop;
$persons->insert( { id => 1, name => 'Joe', city => 'Dallas', country => 'US', type => '20' } );

# END Prepare test data --------------------------------------------------------

Gideon->register_store( 'gideon', Example::Driver::Mongo->new );

my $persons = Mongo::Person->find_all( country => 'US', { order_by => { desc => 'name' }, limit => 10 } );
my $first = $persons->first;

is( $persons->is_empty, 0,     'Not empty!' );
is( $persons->length,   1,     'Total results' );
is( $first->name,       'Joe', 'Results as object' );

my $new_person = Mongo::Person->new( name => 'Foo', city => 'Vegas', country => 'US', type => 11 );
$new_person->save;

sub mongo_not_running {
    try { Example::Driver::Mongo->connect(); return undef } catch { return 1 }
}

sub mongo_not_installed {

    try { use MongoDB; return undef }
    catch { return 1 };

}
