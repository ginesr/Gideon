#!/usr/bin/perl

use lib '.lib/';
use strict;
use Test::More tests => 3;
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
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_name = ? ) ORDER BY country.country_iso',
        bound_params => ['arg'],
        results      => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_name = ? ) ORDER BY country.country_iso, country.country_name',
        bound_params => ['arg'],
        results      => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement => 'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_name = ? ) ORDER BY country.country_name DESC',
        bound_params => ['arg'],
        results      => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

my $record;

Gideon->register_store( 'master', $dbh );

lives_ok(
    sub {
        $record = Example::Country->find_all( name => 'arg', { order_by => 'iso' } );
    },
    'One straight order'
);

lives_ok(
    sub {
        $record = Example::Country->find_all( name => 'arg', { order_by => [ 'iso', 'name' ] } );
    },
    'Order two columns'
);

lives_ok(
    sub {
        $record = Example::Country->find_all( name => 'arg', { order_by => { desc => 'name' } } );
    },
    'Order one column with direction'
);
