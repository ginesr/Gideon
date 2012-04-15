#!perl

use lib './lib';
use strict;
use Test::More;
use Try::Tiny;
use Data::Dumper qw(Dumper);
use Test::Exception;

if ( mongo_not_installed() ) {
    plan skip_all => 'MongoDB module not installed';
} elsif ( mongo_not_running() ) {
    plan skip_all => 'Mongo daemon not running on localhost';
} else {
    plan tests => 24;
}

use_ok(qw( Example::Driver::Mongo));
use_ok(qw(Mongo::Person));
use_ok(qw(MongoDB) );

# Prepare test data ------------------------------------------------------------

my $conn    = MongoDB::Connection->new;
my $db      = $conn->gideon;
my $persons = $db->person;

$persons->drop;

$persons->insert( { id => 1, name => 'Joe',  city => 'Dallas',   country => 'US', type => 10 } );
$persons->insert( { id => 2, name => 'Jane', city => 'New York', country => 'US', type => 20 } );
$persons->insert( { id => 3, name => 'Don',  city => 'New York', country => 'US', type => 30 } );

sleep(2); # i know this is stupid, sorry

# END Prepare test data --------------------------------------------------------

Gideon->register_store( 'gideon', Example::Driver::Mongo->new );

$persons = Mongo::Person->find_all( country => 'US', { order_by => { desc => 'name' }, limit => 10 } );
my $first = $persons->first;

is( $persons->is_empty, 0,     'Not empty!' );
is( $persons->length,   3,     'Total results' );
is( $first->name,       'Joe', 'Results as object' );

$first->name('John');

is( $first->is_stored,   1, 'Object is stored' );
is( $first->is_modified, 1, 'Object was changed' );

lives_ok(
    sub {
        $first->save;
    },
    'Update record'
);

my $new_person = Mongo::Person->new( name => 'Foo', city => 'Vegas', country => 'US', type => 11 );

lives_ok(
    sub {
        $new_person->save;
    },
    'Insert record'
);

my $new_delete = Mongo::Person->new( name => 'Bar', city => 'Miami', country => 'US', type => 10 );
lives_ok(
    sub {
        $new_delete->save;
    },
    'Insert for deletion'
);

my $stored = Mongo::Person->find( name => 'Bar' );

is( $stored->name,        'Bar',   'Using find() name' );
is( $stored->city,        'Miami', 'Using find() city' );
is( $stored->is_stored,   1,       'Using find() is stored' );
is( $stored->is_modified, undef,   'Using find() was changed' );

lives_ok(
    sub {
        $stored->remove;
    },
    'Remove stored object'
);

my $not_existent = Mongo::Person->find( name => 'Bar' );
is( $not_existent, undef, 'No results using find()' );

my $list = Mongo::Person->find_all( city => { like => 'york' } );

is( $list->is_empty, 0, 'Not empty!' );
is( $list->length,   2, 'Total results using like' );

my $greater = Mongo::Person->find_all( type => { gt => 20 } );
is( $greater->length,   1, 'Total results using gt' );

my $greatereq = Mongo::Person->find_all( type => { gte => 20 } );
is( $greatereq->length,   2, 'Total results using gte' );

my $not = Mongo::Person->find_all( name => { not => 'John' } );
my $rec_not = $not->first;

is( $rec_not->name, 'Jane', 'Filters using not' );

my $lt = Mongo::Person->find_all( type => { lt => 20 } );
is( $lt->length,   2, 'Total results using lt' );

my $eq = Mongo::Person->find_all( city => 'Dallas' );
is( $eq->length,   1, 'Total results using eq' );

# Prerequisites for running tests ----------------------------------------------

sub mongo_not_running {

    try { 
        use Example::Driver::Mongo;
        Example::Driver::Mongo->connect();
        return undef 
    } catch { return 1 }

}

sub mongo_not_installed {

    try { use MongoDB; return undef } catch { return 1 };

}
