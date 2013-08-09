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

plan tests => 8;

use_ok(qw(Gideon::DB::Driver::MySQL));
use_ok(qw(Example::Test));

# Prepare test data ------------------------------------------------------------
prepare_test_data();

# ------------------------------------------------------------------------------

my $driver = Gideon::DB::Driver::MySQL->new(
    db          => 'test',
    username    => 'test',
    host        => 'localhost',
    raise_error => 1,
);

Gideon->register_store( 'mysql_server', $driver );

my $before = Example::Test->function( count => '*' );

Gideon->transaction('mysql_server')->begin_work;

Example::Test->new( name => 'Foo', value => 'Lala' )->save;
Example::Test->new( name => 'Bar', value => 'Lala' )->save;

my $middle = Example::Test->function( count => '*' );

Gideon->transaction('mysql_server')->rollback;

my $after = Example::Test->function( count => '*' );

is( $before, 0, 'Record count before' );
is( $middle, 2, 'Record count in the middle' );
is( $after,  0, 'Record count after' );

Gideon->transaction('mysql_server')->begin_work;

my $fresh = Example::Test->function( count => '*' );

Example::Test->new( name => 'Foo', value => 'Lala' )->save;
Example::Test->new( name => 'Bar', value => 'Lala' )->save;

my $inside = Example::Test->function( count => '*' );

Gideon->transaction('mysql_server')->commit;

my $outside = Example::Test->function( count => '*' );

is( $fresh, 0, 'Record count with regular handler' );
is( $inside, 2, 'Record count inside' );
is( $outside, 2, 'Record count after commit' );

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t1 = qq~create table gideon_t1 (id int not null auto_increment, name varchar(20) not null, value text not null, primary key (id), key (name))~;

    $dbh->do('drop table if exists gideon_t1');
    $dbh->do($create_t1);

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
