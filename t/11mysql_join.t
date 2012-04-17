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
} else {
    plan tests => 13;
}

use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::My::Person));
use_ok(qw(Example::My::Address));

# Prepare test data ------------------------------------------------------------
prepare_test_data();

# ------------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

Gideon->register_store( 'mysql_master', $driver );

# find all addresses for person whom id is 1 ordered by address Id
my $records = Example::My::Person->find_by_address( id => 1, { order => 'gideon_j2.id' } );
my $first   = $records->first;
my $last    = $records->last;

is( $first->{'gideon_j1.id'},      1,          'First record id' );
is( $last->{'gideon_j2.id'},       2,          'First record foreing id' );
is( $first->{'gideon_j2.address'}, 'Street 1', 'First record address' );
is( $records->length,              2,          'Total results' );

is( $last->{'gideon_j1.id'},      1,          'Last record id' );
is( $last->{'gideon_j2.id'},      2,          'Last record foreing id' );
is( $last->{'gideon_j2.address'}, 'Street 2', 'Last record address' );

my $record = Example::My::Person->find( id => 1 );
is( $record->name, 'John', 'From mysql one record' );

my $address = Example::My::Address->find( id => 1 );
is( $address->person_id, 1, 'From mysql one record other table' );

throws_ok( sub { my $invalid = Example::My::Person->find_by_address( address => 1 ) }, 'Gideon::Error', 'Using invalid argument' );

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_j1 = qq~create table gideon_j1 (id int not null auto_increment, name varchar(20), primary key (id), key (name))~;

    my $create_j2 = qq~create table gideon_j2 (id int not null auto_increment, person_id int not null, address varchar(50), city varchar(20), primary key (id), key (person_id))~;

    $dbh->do('drop table if exists gideon_j1');
    $dbh->do('drop table if exists gideon_j2');

    $dbh->do($create_j1);
    $dbh->do($create_j2);

    $dbh->do( "insert into gideon_j1 (name) values(?)", undef, "John" );
    $dbh->do( "insert into gideon_j1 (name) values(?)", undef, "Jane" );
    $dbh->do( "insert into gideon_j1 (name) values(?)", undef, "Brad" );
    $dbh->do( "insert into gideon_j1 (name) values(?)", undef, "Tom" );

    $dbh->do( "insert into gideon_j2 (person_id,address,city) values(?,?,?)", undef, 1, "Street 1", 'NY' );
    $dbh->do( "insert into gideon_j2 (person_id,address,city) values(?,?,?)", undef, 1, "Street 2", 'NY' );
    $dbh->do( "insert into gideon_j2 (person_id,address,city) values(?,?,?)", undef, 2, "Jane home", 'SF' );
    $dbh->do( "insert into gideon_j2 (person_id,address,city) values(?,?,?)", undef, 4, "Tom's house", 'LA' );

}

sub mysql_not_installed {
    return;
}
