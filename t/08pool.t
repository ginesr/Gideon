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
else {
    plan tests => 19;
}

use_ok(qw(Gideon::Connection::Pool));
use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::Test));
use_ok(qw(Example::Test2));

my $dir = getcwd;
if ( $dir !~ /\/t/ ) { chdir('t') }

my $driver_1 = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

my $driver_2 = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => '127.0.0.1'
);

my $driver_3 = Example::Driver::MySQL->new(
    db       => 'mysql',
    username => 'root',
    password => 'secret',
    host     => '127.0.0.1'
);

my $pool = Gideon::Connection::Pool->new;
$pool->push( 'node1', $driver_1 );
$pool->push( 'node2', $driver_2 );
$pool->push( 'node3', $driver_3 );

# Prepare test data ------------------------------------------------------------
prepare_test_data();
# ------------------------------------------------------------------------------

Gideon->register_store( 'mysql_server', $pool );

throws_ok(
    sub { Gideon->storage->select('node1') },
    qr/\Quse select() from your own class\E/,
    'Try to use select pool from base class'
);

throws_ok( sub { Gideon->storage->from_pool( $pool, 'node1') },
    qr/\Quse from_pool() from your own class\E/, 'Not selected yet' );

throws_ok(
    sub { Example::Test->storage->select('foo') },
    qr/invalid identifier/,
    'Invalid pool identifier'
);

throws_ok(
    sub { Example::Test->storage->last_used },
    qr/your store is a connection pool but/,
    'Try to use select pool from base class'
);

Example::Test->storage->select('node1');
Example::Test2->storage->select('node3');

throws_ok( sub { Example::Test2->find( id => 4 ) },
    'Example::Error::Simple', 'Tried to use conn from pool that failed' );

my $test_data = Example::Test->find_all( undef, { limit => 5 } );
my $first     = $test_data->first;
my $last      = $test_data->last;

is( $first->name, 'rec 1', 'From mysql first record' );
is( $last->name,  'rec 5', 'From mysql last record with limit' );

Example::Test->storage->select('node2');

my $record = Example::Test->find( id => 4 );
is( $record->name, 'rec 4', 'From mysql one record' );

Example::Test->storage->select('node3');

throws_ok( sub { $record = Example::Test->find( id => 4 ) },
    'Example::Error::Simple', 'Tried to use conn from pool that failed' );

$record = Example::Test->find( id => 3, { conn => 'node1' } );

is( $record->name, 'rec 3', 'Using node from param' );

my $new_rec = Example::Test->new( name => 'is brand new', value => 'some value' );
$new_rec->conn('node1');  
$new_rec->save();

my $id = $new_rec->last_inserted_id();

is( $id, 11, 'New record inserted' );

my $nw_record = Example::Test->find( id => 11, { conn => 'node2' } );
$nw_record->name('not so new now');

is($nw_record->is_stored, 1, 'Is stored');
is($nw_record->conn, 'node2', 'After find pool is set');

$nw_record->conn('node2');

is($nw_record->conn, 'node2', 'Changed to pool before save');

lives_ok( sub { $nw_record->save() }, 'Save record using pool' );

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
    try { use DBD::mysql; return undef }
    catch { return 1 };

}
