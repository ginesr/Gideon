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

plan tests => 10;

use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::Lazy));

# Prepare test data ------------------------------------------------------------
prepare_test_data();
# ------------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

Gideon->register_store( 'mysql', $driver );

my $johnson = Example::Lazy->find( name => 'Johnson' );

is($johnson->id,2,'ID OK');
is($johnson->order,1,'Order OK');

like($johnson,qr/^Example::Lazy \(2\)/,'String with class and id');
like($johnson,qr/"order": "1"/,'String with lazy attribute value');

my $doe = Example::Lazy->new( name => 'Doe');

like($doe,qr/^Example::Lazy \{/,'String with class and no id');
like($doe,qr/"order\[lazy\]": null/,'String with lazy attribute not intialized');

is($doe->order,10,'New order OK');

$doe->save;

like($doe,qr/"order": 10/,'String with lazy attribute after save');

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );
    my @names = qw(Smith Johnson Williams Brown Jones Miller Davis Garcia 
        Rodriguez Wilson);
    my $create_t1 = qq~create table gideon_t4 (
        `id` int not null auto_increment, 
        `name` varchar(20), 
        `order` int null, 
        primary key (`id`), key (`name`))~;

    $dbh->do('drop table if exists gideon_t4');
    $dbh->do($create_t1);

    for ( 0 .. 9 ) {
        $dbh->do( "insert into gideon_t4 (`name`,`order`) values(?,?)",
            undef, $names[$_], $_ );
    }

}

sub mysql_not_installed {
    try { use DBD::mysql; return undef }
    catch { return 1 }
}

sub mysql_cant_connect {
    
    my $test_db = 'database=test;host=;port=';
    my $test_user = 'test';
    my $test_pass = '';
    
    if ($ENV{'GIDEON_DBI_TEST_DB'}) {
        $test_db = $ENV{GIDEON_DBI_TEST_DB}; 
    }
    if ($ENV{'GIDEON_DBI_TEST_USER'}) {
        $test_user = $ENV{GIDEON_DBI_TEST_USER}; 
    }
    if ($ENV{'GIDEON_DBI_TEST_PASS'}) {
        $test_user = $ENV{GIDEON_DBI_TEST_PASS}; 
    }
    
    try { DBI->connect( "dbi:mysql:$test_db", $test_user, $test_pass ) or die; return undef }
    catch { return 1 }
}