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
    plan tests => 12;
}

use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::Test));

# Prepare test data ------------------------------------------------------------
prepare_test_data();
# ------------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

Gideon->register_store( 'mysql_server', $driver );

my $test_data = Example::Test->find_all( undef, { limit => 5 } );
my $first     = $test_data->first;
my $last      = $test_data->last;

is( $first->name, 'rec 1', 'From mysql first record' );
is( $last->name,  'rec 5', 'From mysql last record with limit' );

my $record = Example::Test->find( id => 4 );
is( $record->name, 'rec 4', 'From mysql one record' );

throws_ok(
    sub { $record = Example::Test->find( id => 3, { conn => 'node1' } ) },
    qr/can't use node1 without pool configuration/, 'Failed to use pool here' );

my $new_rec =
  Example::Test->new( name => 'is brand new', value => 'some value' );
$new_rec->save();

is( $new_rec->id, 11, 'New record inserted' );

my $id = $new_rec->last_inserted_id();

is( $id, 11, 'Last id from db' );

throws_ok(sub { my $not_found = Example::Test->find( id => 9999 ) }, 'Gideon::Error::DBI::NotFound');

my $find_again = Example::Test->find( id => 11 );

is( $find_again->id, 11, 'Again last id from db' );
is( $find_again->name, 'is brand new', 'Again name from db' );

$find_again->name('not so new');
$find_again->save();

is( $find_again->id, 11, 'Again after save' );

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t1 =
qq~create table gideon_t1 (id int not null auto_increment, name varchar(20), value text, primary key (id), key (name))~;

    $dbh->do('drop table if exists gideon_t1');
    $dbh->do($create_t1);

    for ( 1 .. 10 ) {
        $dbh->do( "insert into gideon_t1 (name,value) values(?,?)",
            undef, "rec $_", "value of $_" );
    }

}

sub mysql_not_installed {
    return;
}
