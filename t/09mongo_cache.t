#!perl

use lib 'xlib';
use strict;
use Test::More;
use Try::Tiny;
use Data::Dumper qw(Dumper);
use Test::Exception;
use Test::Memcached;

if ( mongo_not_installed() ) {
    plan skip_all => 'MongoDB module not installed';
} elsif ( mongo_not_running() ) {
    plan skip_all => 'Mongo daemon not running on localhost';
} else {
    plan tests => 33;
}

use_ok(qw(Example::Driver::Mongo));
use_ok(qw(Mongo::Person));
use_ok(qw(MongoDB));
use_ok(qw(Gideon::Cache::Memcache));

# Test memcache daemon
my $memdtest = Test::Memcached->new( options => { user => 'nobody' } );
$memdtest->start;
ok($memdtest,'Memcached running');
my $port = $memdtest->option('tcp_port');

# Register cache
Gideon->register_store( 'gideon', Example::Driver::Mongo->new );
Gideon->register_cache( 'Gideon::Cache::Memcache' );

Gideon::Cache::Memcache->set_servers( ["127.0.0.1:$port"] );

# Prepare test data ------------------------------------------------------------

my $conn   = MongoDB::Connection->new;
my $db     = $conn->get_database('gideon');
my $person = $db->get_collection('person');

$person->drop;

$person->insert( { id => 1, name => 'Joe',  city => 'Dallas',   country => 'US', type => 10 } );
$person->insert( { id => 2, name => 'Jane', city => 'New York', country => 'US', type => 20 } );
$person->insert( { id => 3, name => 'Don',  city => 'New York', country => 'US', type => 30 } );

is($person->count,3,'Three test records');

# END Prepare test data --------------------------------------------------------

my $persons = Mongo::Person->find_all( country => 'US', { order_by => { desc => 'name' }, limit => 10 } );
my $first = $persons->first;

is( $persons->has_no_records, 0,     'Not empty!' );
is( $persons->records_found,   3,     'Total results' );
is( $first->name,       'Joe', 'Results as object' );

$first->name('John');

is( $first->is_stored,   1, 'Object is stored' );
is( $first->is_modified, 1, 'Object was changed' );

my $hash = Gideon::Cache::Memcache->_get_class_cache;
my $classes = scalar keys %$hash;

is($classes,1,'One class found in cache');

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
is( $stored->is_modified, 0,       'Using find() was changed' );

lives_ok(
    sub {
        $stored->remove;
    },
    'Remove stored object'
);

my $not_existent = Mongo::Person->find( name => 'Bar' );
is( $not_existent, undef, 'No results using find()' );

my $list = Mongo::Person->find_all( city => { like => 'york' } );

is( $list->has_no_records, 0, 'Not empty!' );
is( $list->records_found,   2, 'Total results using like' );

my $greater = Mongo::Person->find_all( type => { gt => 20 } );
is( $greater->records_found,   1, 'Total results using gt' );

my $greatereq = Mongo::Person->find_all( type => { gte => 20 } );
is( $greatereq->records_found,   2, 'Total results using gte' );

my $not = Mongo::Person->find_all( name => { ne => 'John' } );
my $rec_not = $not->first;

is( $rec_not->name, 'Jane', 'Filters using not' );

my $lt = Mongo::Person->find_all( type => { lt => 20 } );
is( $lt->records_found,   2, 'Total results using lt' );

my $eq = Mongo::Person->find_all( city => 'Dallas' );
is( $eq->records_found,   1, 'Total results using eq' );

my $lte = Mongo::Person->find_all( type => { lte => 11 } );
is( $lte->records_found,   2, 'Total results using lte' );

my $jane = Mongo::Person->find( name => 'Jane' );
is($jane->name,'Jane','Find record');

my $total_keys = scalar Gideon::Cache::Memcache->class_keys('Mongo::Person');
is($total_keys,8,'Total keys in cache');

$person->drop;

is($person->count,0,'No test records');

my $jane_cached = Mongo::Person->find( name => 'Jane' );
is($jane_cached->name,'Jane','Find cached record');

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
