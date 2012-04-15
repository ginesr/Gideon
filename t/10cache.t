#!perl

use lib './lib';
use strict;
use Try::Tiny;
use Test::More;
use Data::Dumper qw(Dumper);
use Cwd;
use DBI;
use Test::Exception;

if ( mysql_not_installed() ) {
    plan skip_all => 'MySQL driver not installed';
}
else {
    plan tests => 9;
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

my $test_data = Example::Cache->find_all( value => { like => 'test 5' } );
my $first     = $test_data->first;

is( $first->id, 5, 'Record from db using like' );

is( Gideon::Cache->count, 1, 'One key in the cache' );
is( Gideon::Cache->hits, 0, 'No hits' );

my $cached_data  = Example::Cache->find_all( value => { like => 'test 5' } );
my $first_cached = $cached_data->first;

is( $first_cached->id, 5, 'Record from cache' );

is( Gideon::Cache->hits, 1, 'One hit after running same search' );
is( Gideon::Cache->count, 1, 'Still one key in the cache' );

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

sub mysql_not_installed {
    return;
}
