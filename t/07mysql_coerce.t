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
    plan tests => 9;
}

use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::My::Lastlog));

# Prepare test data ------------------------------------------------------------
prepare_test_data();

# ------------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

Gideon->register_store( 'mysql', $driver );

my $date = Date::Simple->new( year => 2012, month => 4, day => 20 );
is( $date->year, 2012, 'Year' );

my $coerce = Example::My::Lastlog->new(
    id      => 1,
    name    => 'Foo',
    lastlog => '2011-08-18 20:06:45',
);

is( $coerce->lastlog, '2011-08-18 20:06:45', 'Last log is a timestamp' );
is( $coerce->lastlog->year, 2011, 'Last log is coerced' );

my $person = Example::My::Lastlog->find( name => 'John' );

is( $person->lastlog, '2001-01-02 10:11:12', 'Last log is a timestamp' );
is( $person->lastlog->year, 2001, 'Last log is coerced' );

$person->lastlog->year(2012);
$person->save;

my $person_again = Example::My::Lastlog->find( name => 'John' );

is( $person_again->lastlog, '2012-01-02 10:11:12', 'Last log was updated' );
is( $person_again->lastlog->year, 2012, 'Last log is coerced' );

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t3 =
qq~create table gideon_t3 (id int not null auto_increment, name varchar(20), `timestamp` timestamp, primary key (id), key (name))~;

    $dbh->do('drop table if exists gideon_t3');
    $dbh->do($create_t3);

    $dbh->do( "insert into gideon_t3 (name,timestamp) values(?,?)",
        undef, "John", "2001-01-02 10:11:12" );

    $dbh->do( "insert into gideon_t3 (name,timestamp) values(?,now())",
        undef, "Jane" );
}

sub mysql_not_installed {
    try { use DBD::mysql; return undef }
    catch { return 1 };
}