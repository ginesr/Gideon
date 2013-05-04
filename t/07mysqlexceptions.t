#!perl

use lib 'xlib';
use strict;
use Try::Tiny;
use Test::More;
use Data::Dumper qw(Dumper);
use Cwd;
use DBI;
use Test::Exception;
use Try::Tiny;

if ( mysql_not_installed() ) {
    plan skip_all => 'MySQL driver not installed';
}

if ( mysql_cant_connect() ) {
    plan skip_all => 'Can\'t connect to local mysql using `test` user & db';
}

plan tests => 8;

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

my $one = Example::Test->new(
    name  => 'Test',
    value => 1
);
$one->save;

throws_ok(
    sub {
        my $two = Example::Test->new(
            name  => 'Test',
            value => 2
        );
        $two->save;
    },
    'Gideon::Error::DBI',
    'Dies on duplicate key'
);

try {
    my $two = Example::Test->new(
        name  => 'Test',
        value => 2
    );
    $two->save;
}
catch {
    
    my $e = shift;

    like( "$e", qr/Duplicate entry/, 'Error message strigified' );

    like( $e->msg, qr/Duplicate entry/, 'Error message from driver' );
    like( $e->stmt, qr/INSERT INTO gideon_t1 \( `name`, `value`\) VALUES \( \?, \? \)/, 'Failed query' );
    
    is( $e->params->[0], 'Test', 'Params failed' );
    is( $e->params->[1], '2',    'Params failed' );

};

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t1 = qq~create table gideon_t1 
    (id int not null auto_increment, name varchar(20), value text, 
    primary key (id), 
    unique key (name))
    ~;

    $dbh->do('drop table if exists gideon_t1');
    $dbh->do($create_t1);

    for ( 1 .. 10 ) {
        $dbh->do( "insert into gideon_t1 (name,value) values(?,?)", undef, "rec $_", "value of $_" );
    }

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
