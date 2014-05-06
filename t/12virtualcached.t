#!perl

use lib 'xlib';
use strict;
use Try::Tiny;
use Test::More;
use Data::Dumper qw(Dumper);
use DBI;
use Test::Exception;

if ( mysql_not_installed() ) {
    plan skip_all => 'MySQL driver not installed';
}

if ( mysql_cant_connect() ) {
    plan skip_all => 'Can\'t connect to local mysql using `test` user & db';
}

plan tests => 16;

use_ok(qw(Gideon::Virtual));
use_ok(qw(Gideon::Virtual::Provider));
use_ok(qw(Gideon::DB::Driver::MySQL));
use_ok(qw(Gideon::Cache::Hash));
use_ok(qw(Example::Virtual::Person));
use_ok(qw(Example::Virtual::PersonJoinAddress));
use_ok(qw(Example::Virtual::Provider));

# Prepare test data ------------------------------------------------------------
prepare_test_data();
# ------------------------------------------------------------------------------

my $driver = Gideon::DB::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

my $provider = Example::Virtual::Provider->new;
$provider->driver($driver);

is( Gideon->cache->ttl, 300, 'Dafault time to live in cache' );

Gideon->register_store( 'mysql', $driver );
Gideon->register_store( 'virtual', $provider );
Gideon->register_cache( 'Gideon::Cache::Hash' );

my $results = Example::Virtual::PersonJoinAddress->find_all( person_id => 1 );
my $first   = $results->first;
my $last    = $results->last;

is( $first->name,            'person 1',              'From join first record name' );
is( $first->address,         'person1 first address', 'From join first record address' );
is( $last->name,             'person 1',              'From join last record name' );
is( $last->address,          'person1 third address', 'From join last record address' );
is( $results->records_found, 3,                       'Total results' );

#warn Dumper(Gideon::Cache->content);
empty_tables();

throws_ok(sub{Example::Virtual::Person->find(id=>1)},'Gideon::Error::DBI::NotFound','No records');

Example::Virtual::PersonJoinAddress->find_all( person_id => 1 );

is( Gideon::Cache::Hash->hits,  1, 'One hit after running same search' );
is( Gideon::Cache::Hash->count, 1, 'Still one key in the cache' );

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t1 = qq~create table gideon_virtual_person (id int not null auto_increment, name varchar(20), value text, primary key (id), key (name))~;

    my $create_t2 =
      qq~create table gideon_virtual_address (id int not null auto_increment, person_id int not null, address text, primary key (id), key (person_id))~;

    drop_tables();

    $dbh->do($create_t1);
    $dbh->do($create_t2);

    for ( 1 .. 10 ) {
        $dbh->do( "insert into gideon_virtual_person (name,value) values(?,?)", undef, "person $_", "value of $_" );
    }

    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 1, "person1 first address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 1, "person1 second address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 1, "person1 third address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 5, "person5 first address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 5, "person5 other address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 7, "person7 first address" );
    
}

sub drop_tables {
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );
    $dbh->do('drop table if exists gideon_virtual_person');
    $dbh->do('drop table if exists gideon_virtual_address');
}

sub empty_tables {
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );
    $dbh->do('truncate table gideon_virtual_person');
    $dbh->do('truncate table gideon_virtual_address');
}

sub mysql_not_installed {
    try { use DBD::mysql; return undef } catch { return 1 };
}

sub mysql_cant_connect {

    my $test_db   = 'database=test;host=;port=';
    my $test_user = 'test';
    my $test_pass = '';

    if ( $ENV{'GIDEON_DBI_TEST_DB'} ) {
        $test_db = $ENV{GIDEON_DBI_TEST_DB};
    }
    if ( $ENV{'GIDEON_DBI_TEST_USER'} ) {
        $test_user = $ENV{GIDEON_DBI_TEST_USER};
    }
    if ( $ENV{'GIDEON_DBI_TEST_PASS'} ) {
        $test_user = $ENV{GIDEON_DBI_TEST_PASS};
    }

    try { DBI->connect( "dbi:mysql:$test_db", $test_user, $test_pass ) or die; return undef } catch { return 1 };
}
