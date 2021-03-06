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
    plan tests => 10;
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

Example::Cache->cache->disable;

my $test_data = Example::Cache->find_all( value => { like => '%test 5' } );
my $first     = $test_data->first;

is( $first->id, 5, 'Record from db using like' );

is( Gideon::Cache::Hash->count, 0, 'Cache disabled' );
is( Gideon::Cache::Hash->hits, 0, 'No hits' );

my $more_data = Example::Cache->find_all( value => { like => '%test 6' } );

my @list = Gideon::Cache::Hash->class_keys('Example::Cache'); 

is( scalar @list, 0, 'Keys for class' );

empty_table();

my $cached_data = Example::Cache->find_all( value => { like => '%test 5' } );

is( $cached_data->records_found, 0, 'No records found' );

is( Gideon::Cache::Hash->hits, 0, 'No hits in cache' );
is( Gideon::Cache::Hash->count, 0, 'Nothing on cache to count' );

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
