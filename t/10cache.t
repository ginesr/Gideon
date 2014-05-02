#!perl

use lib 'xlib';
use strict;
use Try::Tiny;
use Test::More;
use Data::Dumper qw(Dumper);
use DBI;

if ( mysql_not_installed() ) {
    plan skip_all => 'MySQL driver not installed';
}
else {
    plan tests => 13;
}

use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::Cache));
use_ok(qw(Gideon::Cache::Hash));

# Prepare test data ------------------------------------------------------------
prepare_test_data();
# ------------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

Gideon->register_store( 'mysql_server', $driver );
Gideon->register_cache( 'Gideon::Cache::Hash' );
Gideon->cache->ttl( 86400 ); # one day

my $test_data = Example::Cache->find_all( value => { like => '%test 5' } );
my $first     = $test_data->first;

is( $first->id, 5, 'Record from db using like' );

is( Gideon->cache->ttl, 86400, 'Time to live in cache' );
is( Gideon::Cache::Hash->count, 1, 'One key in the cache' );
is( Gideon::Cache::Hash->hits, 0, 'No hits' );

my $more_data = Example::Cache->find_all( value => { like => '%test 6' } );

my @list = Gideon::Cache::Hash->class_keys('Example::Cache'); 

is( scalar @list, 2, 'Keys for class' );

Example::Cache->find( name => 'test 1' );

empty_table();

my $cached_data  = Example::Cache->find_all( value => { like => '%test 5' } );
my $first_cached = $cached_data->first;

is( $first_cached->id, 5, 'Record from cache' );

is( Gideon::Cache::Hash->hits, 1, 'One hit after running same search' );
is( Gideon::Cache::Hash->count, 3, 'Still one key in the cache' );

my $cached_find_all  = Example::Cache->find_all( name => 'test 1' );
my $cached_find = Example::Cache->find( name => 'test 1' );

isa_ok($cached_find_all, 'Gideon::DBI::Results');
isa_ok($cached_find, 'Example::Cache');

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
