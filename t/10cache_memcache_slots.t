#!perl

use lib 'xlib';
use strict;
use Test::Exception;
use Test::More;
use Data::Dumper qw(Dumper);
use DBI;
use Test::Memcached;

my $memdtest = Test::Memcached->new( options => { user => 'nobody' } );
$memdtest->start;
my $port = $memdtest->option('tcp_port');

if ( mysql_not_installed() ) {
    plan skip_all => 'MySQL driver not installed';
}
else {
    plan tests => 17;
}

use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::Cache));
use_ok(qw(Gideon::Cache::Memcache));

# Prepare test data ------------------------------------------------------------
prepare_test_data();
# ------------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

# setup ------------------------------------------------------------------------

Gideon->register_store( 'mysql_server', $driver );
Gideon->register_cache( 'Gideon::Cache::Memcache' );

Gideon::Cache::Memcache->set_servers( ["127.0.0.1:$port"] );
Gideon::Cache::Memcache->add_class_ttl('Example::Cache', 20);

# ------------------------------------------------------------------------------

is( Gideon::Cache::Memcache->count, 0, 'No keys in cache (default)' );

Gideon::Cache::Memcache->set_slot('TEST_1');

my $first_slot1 = Example::Cache->find_all( id => 1 )->first;
is( $first_slot1->id, 1, 'Record from db' );

is( Gideon::Cache::Memcache->count, 1, 'One key stored in cache (slot 1)' );
is( Gideon::Cache::Memcache->hits, 0, 'No hits (slot 1)' );

Gideon::Cache::Memcache->set_slot('TEST_2');

my $first_slot2 = Example::Cache->find_all( id => 2 )->first;
is( $first_slot2->id, 2, 'Record from db' );

is( Gideon::Cache::Memcache->slot_count, 3, '3 slots now (2 plus default)' );
is( Gideon::Cache::Memcache->count, 1, 'One keys stored in cache (slot 2)' );
is( Gideon::Cache::Memcache->hits, 0, 'No hits (slot 2)' );

# clear db ---------------------------------------------------------------------
empty_table();
# ------------------------------------------------------------------------------

my $first_slot2_cached = Example::Cache->find_all( id => 2 )->first;

is( Gideon::Cache::Memcache->hits, 1, 'One hit to (slot 2)' );

Gideon::Cache::Memcache->set_slot('TEST_1');

my $first_slot1_cached = Example::Cache->find_all( id => 1 )->first;

is( Gideon::Cache::Memcache->hits, 2, 'Two hits (slot 1 + slot 2)' );

# clear one slot
$first_slot1_cached->value('modified');
$first_slot1_cached->save;

is( Gideon::Cache::Memcache->count, 0, 'Clear keys in cache (slot 1 none, one key remains in slot 2)' );

Gideon::Cache::Memcache->set_slot('TEST_2');

is( Gideon::Cache::Memcache->count, 1, 'Got keys count from cache (slot 2 only, slot 1 is empty now)' );

# clear all slots
$first_slot2_cached->value('modified two');
$first_slot2_cached->save;

is( Gideon::Cache::Memcache->count, 0, 'No keys in cache (all slots empty)' );

Gideon::Cache::Memcache->default_slot;

lives_ok( sub { $memdtest->stop } , 'Stop daemon' );

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t2 =
qq~create table gideon_t2 (id int not null auto_increment, name varchar(20), value text, primary key (id), key (name))~;

    $dbh->do('drop table if exists gideon_t2');
    $dbh->do($create_t2);

    for ( 1 .. 10 ) {
        $dbh->do( "insert into gideon_t2 (name,value) values(?,?)",
            undef, "test $_", "value of test $_" );
    }

}

sub empty_table {
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );
    $dbh->do('truncate table gideon_t2');
}

sub mysql_not_installed {
    try { use DBD::mysql; return undef }
    catch { return 1 };
}
