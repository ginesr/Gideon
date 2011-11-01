#!/usr/bin/perl

use lib '.lib/';
use strict;
use Test::More tests => 3;
use Example::Person;
use Data::Dumper qw(Dumper);
use DBD::Sqlite;
use Cwd;
use Example::Driver::SQLite;

my $dir = getcwd;
if ( $dir !~ /\/t/ ) { chdir('t') }

# Prepare test data ------------------------------------------------------------

my $dbh = DBI->connect( "dbi:SQLite:dbname=test.db", "", "" );

$dbh->do("drop table person");
$dbh->do(
    "CREATE TABLE person
(
       person_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       person_name VARCHAR(150) NOT NULL,
       person_city TEXT,
       person_country TEXT,
       person_type INTEGER
)
"
);

$dbh->do("insert into person (person_name,person_city,person_country,person_type) values ('John Doe','Las Vegas','US',10)");
$dbh->do("insert into person (person_name,person_city,person_country,person_type) values ('John John','San Francisco','US',10)");
$dbh->do("insert into person (person_name,person_city,person_country,person_type) values ('Foo Bar','Buenos Aires','AR',10)");

# END Prepare test data --------------------------------------------------------

Gideon->register_store( 'master', Example::Driver::SQLite->new( db => 'test.db' ) );

my $persons = Example::Person->find_all( country => 'US', { order_by => { desc => 'name' }, limit => 10 } );
my $first = $persons->first;

is( $persons->is_empty, 0,          'Not empty!' );
is( $persons->length,   2,          'Total results' );
is( $first->name,       'John Doe', 'Results as object' );
