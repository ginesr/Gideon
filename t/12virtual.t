#!perl

use lib 'xlib';
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

if ( mysql_cant_connect() ) {
    plan skip_all => 'Can\'t connect to local mysql using `test` user & db';
}

plan tests => 13;

use_ok(qw(Gideon::Virtual));
use_ok(qw(Gideon::Virtual::Provider));
use_ok(qw(Gideon::DB::Driver::MySQL));
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

Gideon->register_store( 'my_virtual_store', $provider );

my $results = Example::Virtual::PersonJoinAddress->find_all( person_id => 1 );
my $first   = $results->first;
my $last    = $results->last;

is( $first->name,            'person 1',              'From join first record name' );
is( $first->address,         'person1 first address', 'From join first record address' );
is( $last->name,             'person 1',              'From join last record name' );
is( $last->address,          'person1 third address', 'From join last record address' );
is( $results->records_found, 3,                       'Total results' );

my $no_address = $results->grep( sub { $_->address =~ /no address/ } );

is( $no_address->get_record(0)->name,    'person 1',        'From join then map' );
is( $no_address->get_record(0)->address, 'have no address', 'From join then map' );
is( $no_address->records_found,          1,                 'Only one with no address' );

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t1 = qq~create table gideon_virtual_name (id int not null auto_increment, name varchar(20), value text, primary key (id), key (name))~;

    my $create_t2 =
      qq~create table gideon_virtual_address (id int not null auto_increment, person_id int not null, address text, primary key (id), key (person_id))~;

    $dbh->do('drop table if exists gideon_virtual_name');
    $dbh->do('drop table if exists gideon_virtual_address');

    $dbh->do($create_t1);
    $dbh->do($create_t2);

    for ( 1 .. 10 ) {
        $dbh->do( "insert into gideon_virtual_name (name,value) values(?,?)", undef, "person $_", "value of $_" );
    }

    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 1, "person1 first address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 1, "have no address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 1, "person1 third address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 5, "person5 first address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 5, "person5 other address" );
    $dbh->do( "insert into gideon_virtual_address (person_id,address) values(?,?)", undef, 7, "person7 first address" );
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
