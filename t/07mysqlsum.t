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

plan tests => 14;

use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::Test3));

# Prepare test data ------------------------------------------------------------
prepare_test_data();
# ------------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

Gideon->register_store( 'mysql_server', $driver );

my $sum = Example::Test3->function( sum => 'value', type => 1 );
cmp_ok($sum,'==',20,'Sum numeric value from db');

my $sum_all = Example::Test3->function( sum => 'value');
cmp_ok($sum_all,'==',110,'Sum all numeric value from db');

my @group = Example::Test3->function( sum => 'value', type => { in => [2,3] }, { group_by => ['name'] } );
cmp_ok($group[0]->{sum},'==',40,'Sum grouped by name');
is($group[0]->{name},'second','Name grouped by name');
cmp_ok($group[1]->{sum},'==',50,'Sum grouped by name');
is($group[1]->{name},'third','Name grouped by name');

my @periods = Example::Test3->function( sum => 'value', { group_by => [ { period => "DATE_FORMAT(?,'%Y-%m')" } ] } );
cmp_ok($periods[0]->{sum},'==',20,'Sum grouped by period');
is($periods[0]->{period},'2016-01','Name grouped by period');
cmp_ok($periods[1]->{sum},'==',40,'Sum grouped by period');
is($periods[1]->{period},'2016-02','Name grouped by period');
cmp_ok($periods[2]->{sum},'==',50,'Sum grouped by period');
is($periods[2]->{period},'2016-03','Name grouped by name');

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t1 = qq~create table gideon_t1 (
    id int not null auto_increment, name varchar(20), value int, type int, period date,
    primary key (id), key (name))~;

    $dbh->do('drop table if exists gideon_t1');
    $dbh->do($create_t1);

    for ( 1 .. 2 ) {
        $dbh->do( "insert into gideon_t1 (name,value,type,period) values(?,?,?,?)", undef, "rec $_", 10, 1, '2016-1-1' );
    }

    for ( 1 .. 2 ) {
        $dbh->do( "insert into gideon_t1 (name,value,type,period) values(?,?,?,?)", undef, "second", 20, 2, '2016-2-1' );
    }

    for ( 1 .. 10 ) {
        $dbh->do( "insert into gideon_t1 (name,value,type,period) values(?,?,?,?)", undef, "third", 5 , 3, '2016-3-1' );
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
