#!/usr/bin/perl

use lib '.lib/';
use strict;
use Test::More tests => 2;
use Gideon;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use SQL::Abstract;
use Example::Country;
use Test::Exception;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement    => 'SELECT country_iso, country_name FROM country WHERE ( country_name LIKE ? )',
        bound_params => ['%arg%'],
        results      => [ [ 'country_iso', 'country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement    => 'SELECT country_iso, country_name FROM country WHERE ( ( country_name LIKE ? OR country_name >= ? ) )',
        bound_params => [ '%arg%', 'AR' ],
        results      => [ [ 'country_iso', 'country_name' ], [ 'AR', 'Argentina' ] ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

my $record;

Gideon->register_store( 'master', $dbh );

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
