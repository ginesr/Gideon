#!perl

use lib 'xlib';
use strict;
use Test::Exception;
use Test::More;
use Data::Dumper qw(Dumper);
use DBI;
use Test::Memcached;

if ( mysql_not_installed() ) {
    plan skip_all => 'MySQL driver not installed';
}
elsif ( memcached_fast_installed() ) {
    plan skip_all => 'Memcached Fast not installed';
}
else {
    plan tests => 9;
}

my $memdtest = Test::Memcached->new( options => { user => 'nobody' } );
$memdtest->start;
my $port = $memdtest->option('tcp_port');

ok( $memdtest, 'Memcache daemon' );

use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::Fast));
use_ok(qw(Gideon::Cache::Memcache::Fast));

# Prepare test data ------------------------------------------------------------
prepare_test_data();

# setup ------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

Gideon->register_store( 'mysql_server', $driver );
Gideon->register_cache('Gideon::Cache::Memcache::Fast');

Gideon::Cache::Memcache::Fast->set_servers( ["127.0.0.1:$port"] );

# ------------------------------------------------------------------------------

my $more_data = Example::Fast->find_all( value => { like => '%test 6' } );
my @list = Gideon::Cache::Memcache::Fast->class_keys('Example::Fast');

is( $more_data->records_found, 1, 'One record found' );
is( scalar @list, 1, 'Keys for class' );

empty_table();

my $cached_data = Example::Fast->find_all( value => { like => '%test 6' } );
my $first_cached = $cached_data->first;

is( $cached_data->records_found, 1, 'One record found' );
is( $first_cached->id, 6, 'Record from cache' );

lives_ok( sub { $memdtest->stop } , 'Stop daemon' );

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t2 =
qq~create table gideon_t10Cache (id int not null auto_increment, name varchar(20), value text, primary key (id), key (name))~;

    $dbh->do('drop table if exists gideon_t10Cache');
    $dbh->do($create_t2);

    for ( 1 .. 10 ) {
        $dbh->do( "insert into gideon_t10Cache (name,value) values(?,?)",
            undef, "test $_", "value of test $_" );
    }

}

sub empty_table {
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );
    $dbh->do('truncate table gideon_t10Cache');
}

sub mysql_not_installed {
    try { use DBD::mysql; return undef } catch { return 1 };
}

sub memcached_fast_installed {
    try { use Cache::Memcached::Fast; return undef } catch { return 1 };
}
