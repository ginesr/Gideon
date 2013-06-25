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
use_ok(qw(Gideon::Cache));

# Prepare test data ------------------------------------------------------------
prepare_test_data();
# ------------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

Gideon->register_store( 'mysql_server', $driver );
Gideon->register_cache( 'Gideon::Cache' );

my $test_data = Example::Cache->find_all( value => { like => '%test 5' } );
my $first     = $test_data->first;

is( $first->id, 5, 'Record from db using like' );

is( Gideon::Cache->count, 1, 'One key in the cache' );
is( Gideon::Cache->hits, 0, 'No hits' );

my @list = Gideon::Cache->class_keys('Example::Cache');

is( scalar @list, 1, 'Keys for class' );

my $cached_data  = Example::Cache->find_all( value => { like => '%test 5' } );
my $first_cached = $cached_data->first;

is( $first_cached->id, 5, 'Record from cache' );

$first_cached->value('modified');
$first_cached->save;

my @list_after = Gideon::Cache->class_keys('Example::Cache');

is( Gideon::Cache->hits, 1, 'One hit after running same search' );
is( Gideon::Cache->count, 0, 'No more key in the cache' );
is( scalar @list_after, 0, 'Keys after clear' );

my $after = Example::Cache->find( id => $first_cached->id );
is( $after->value, 'modified', 'Retrieve modified' );
is( Gideon::Cache->count, 1, 'One key in the cache' );

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
