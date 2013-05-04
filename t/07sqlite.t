#!perl

use lib 'xlib';
use strict;
use Try::Tiny;
use Test::More;
use Data::Dumper qw(Dumper);
use Cwd;

if ( sqlite_not_installed() ) {
    plan skip_all => 'SQLite driver not installed';
}
else {
    plan tests => 3;
}

use Example::Driver::SQLite;
use Example::Person;

my $dir = getcwd;
if ( $dir !~ /\/t/ ) { chdir('t') }

# Prepare test data ------------------------------------------------------------

my $dbh = DBI->connect( "dbi:SQLite:dbname=db/test.db", "", "" );

$dbh->do("drop table IF EXISTS person");
$dbh->do(
    "CREATE TABLE person (
       person_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       person_name VARCHAR(150) NOT NULL,
       person_city TEXT,
       person_country TEXT,
       person_type INTEGER
)"
);

$dbh->do("insert into person (person_name,person_city,person_country,person_type) values ('John Doe','Las Vegas','US',10)");
$dbh->do("insert into person (person_name,person_city,person_country,person_type) values ('John John','San Francisco','US',10)");
$dbh->do("insert into person (person_name,person_city,person_country,person_type) values ('Foo Bar','Buenos Aires','AR',10)");

# END Prepare test data --------------------------------------------------------

Gideon->register_store( 'master', Example::Driver::SQLite->new( db => 'db/test.db' ) );

my $persons = Example::Person->find_all( country => 'US', { order_by => { desc => 'name' }, limit => 10 } );
my $first = $persons->first;

is( $persons->has_no_records, 0,           'Not empty!' );
is( $persons->records_found,  2,           'Total results' );
is( $first->name,             'John John', 'Results as object' );

sub sqlite_not_installed {

    try { use DBD::SQLite; return undef } catch { return 1 };

}
