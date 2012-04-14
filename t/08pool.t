#!perl

use lib './lib/';
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
    plan tests => 8;
}

use_ok(qw(Gideon::Connection::Pool));
use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::Test));

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

my $pool = Gideon::Connection::Pool->new;
$pool->push( 'node1', $driver_1 );
$pool->push( 'node2', $driver_2 );

# Prepare test data ------------------------------------------------------------
prepare_test_data();

# ------------------------------------------------------------------------------

Gideon->register_store( 'pool', $pool );

throws_ok(
    sub { Gideon->select('node1') },
    qr/from your class/,
    'Try to use select pool as class'
);

throws_ok( sub { Gideon->get_store_from_pool('node1') },
    qr/to switch/, 'Not selected yet' );
    
throws_ok( sub { Example::Test->select('foo'); },
    qr/invalid identifier/, 'Invalid pool identifier' );

Example::Test->select('node1');

my $test_data = Example::Test->find_all( undef, { limit => 5 } );
my $first     = $test_data->first;
my $last      = $test_data->last;

is( $first->name, 'rec 1', 'From mysql first record' );
is( $last->name,  'rec 5', 'From mysql last record with limit' );

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
