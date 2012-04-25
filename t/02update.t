#!perl

use strict;
use warnings;
use lib 'xlib';
use Test::More tests => 3;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use Example::Country;
use Test::Exception;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement    => 'UPDATE country SET country.country_iso = ?',
        bound_params => ['AR'],
        results      => [ [], [] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_iso = ? )',
        bound_params => ['AR'],
        results      => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ], [ 'AR', 'Argentine' ], ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_iso = ? )',
        bound_params => ['AR'],
        results      => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ], [ 'AR', 'Argentine' ], ]
    },
    {
        statement => 'UPDATE country SET iso = ? WHERE ( country.country_iso = ? )',
        bound_params => ['UY','AR'],
        results => [[],[]]
    },
    
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

my $rows = Example::Country->update( iso => 'AR' );
is( $rows, 1, 'One row updated' );

my $results = Example::Country->find_all( iso => 'AR' );
my $rec = $results->first;

is( $rec->name, 'Argentina', 'First record using results object' );

$rows = Example::Country->find_all( iso => 'AR' )->update( iso => 'UY' );

is( $rows, 1, 'One row updated from results' );
