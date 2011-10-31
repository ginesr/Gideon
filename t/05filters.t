#!/usr/bin/perl

use lib '.lib/';
use strict;
use Test::More tests => 6;
use Gideon;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use SQL::Abstract;
use Example::Country;
use Test::Exception;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_name = ? )',
        bound_params => ['arg'],
        results      => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_name LIKE ? )',
        bound_params => ['%arg%'],
        results      => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( ( country.country_name LIKE ? OR country.country_name >= ? ) )',
        bound_params => [ '%arg%', 'AR' ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( ( ( country.country_name LIKE ? OR country.country_name LIKE ? ) OR country.country_name >= ? ) )',
        bound_params => [ '%arg%', '%ent%', 'AR' ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_name < ? )',
        bound_params => [1],
        results      => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( ( country.country_name <= ? OR country.country_name > ? ) )',
        bound_params => [ 1, 20 ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

my $record;

Gideon->register_store( 'master', $dbh );

lives_ok(
    sub {
        $record = Example::Country->find_all( name => 'arg' );
    },
    'One straight filter'
);

lives_ok(
    sub {
        $record = Example::Country->find_all( name => { like => 'arg' } );
    },
    'One like filter'
);
lives_ok(
    sub {
        $record = Example::Country->find_all( name => { like => 'arg', gte => 'AR' } );
    },
    'Two filters like + gte'
);

lives_ok(
    sub {
        $record = Example::Country->find_all( name => { like => [ 'arg', 'ent' ], gte => 'AR' } );
    },
    'Two filters with 2 like + 1 gte'
);

lives_ok(
    sub {
        $record = Example::Country->find_all( name => { lt => 1 } );
    },
    'lt filter'
);

lives_ok(
    sub {
        $record = Example::Country->find_all( name => { lte => 1 }, name => { gt => 20 } );
    },
    'lt + gt filter with multi filter'
);
