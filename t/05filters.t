#!perl

use lib 'xlib';
use strict;
use Test::More tests => 12;
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
        bound_params => ['arg%'],
        results      => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( ( country.country_name LIKE ? AND country.country_name >= ? ) )',
        bound_params => [ 'arg%', 'AR' ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( ( ( country.country_name LIKE ? OR country.country_name LIKE ? ) AND country.country_name >= ? ) )',
        bound_params => [ 'arg%', 'ent%', 'AR' ],
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
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( ( ( country.country_name LIKE ? AND country.country_name <= ? ) OR country.country_name > ? ) )',
        bound_params => [ 'Afr%', 1, 20 ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'AF', 'Africa' ] ]

    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( ( country.country_name = ? OR country.country_name = ? ) )',
        bound_params => [ 'Argentina', 'Uruguay' ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ], [ 'UY', 'Uruguay' ] ]

    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( ( country.country_name = ? OR country.country_name = ? ) )',
        bound_params => [ 'Argentina', 'Uruguay' ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'AR', 'Argentina' ], [ 'UY', 'Uruguay' ] ]

    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_name != ? )',
        bound_params => [ 'Argentina'  ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'UY', 'Uruguay' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_name NOT LIKE ? )',
        bound_params => [ 'Argentina%'  ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'UY', 'Uruguay' ] ]
    },
    {
        statement =>
          'SELECT country.country_iso as `country.country_iso`, country.country_name as `country.country_name` FROM country WHERE ( country.country_name NOT LIKE ? )',
        bound_params => [ '%Argentina%'  ],
        results => [ [ 'country.country_iso', 'country.country_name' ], [ 'UY', 'Uruguay' ] ]
    },
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

my $record;

Gideon->register_store( 'master', $dbh );

lives_ok(
    sub {
        $record = Example::Country->find( name => 'arg' );
    },
    'One straight filter produces: country_name = ?'
);

lives_ok(
    sub {
        $record = Example::Country->find( name => { like => 'arg%' } );
    },
    'One like filter produces: country_name LIKE ?'
);
lives_ok(
    sub {
        $record = Example::Country->find( name => { like => 'arg%', gte => 'AR' } );
    },
    'Two filters like + gte produces: country_name LIKE ? AND country_name >= ?'
);

lives_ok(
    sub {
        $record = Example::Country->find( name => { like => [ 'arg%', 'ent%' ], gte => 'AR' } );
    },
    'Two filters with 2 like + 1 gte produces: ( country_name LIKE ? OR country_name LIKE ? ) AND country_name >= ? '
);

lives_ok(
    sub {
        $record = Example::Country->find( name => { lt => 1 } );
    },
    'One lt filter produces: country_name < ?'
);

lives_ok(
    sub {
        $record = Example::Country->find( name => { lte => 1 }, name => { gt => 20 } );
    },
    'Two lt + gt filter with multi filter produces: country_name <= ? OR country_name > ?'
);

lives_ok(
    sub {
        $record = Example::Country->find( name => { like => 'Afr%', lte => 1 }, name => { gt => 20 } );
    },
    'like with lt + nested gt with multi filter on same column produces: ( country_name LIKE ? AND country_name <= ? ) OR country_name > ?'
);

lives_ok(
    sub {
        $record = Example::Country->find( name => { eq => ['Argentina','Uruguay'] } );
    },
    'One eq filter with multiple values produces: country_name = ? OR country_name = ?'
);

lives_ok(
    sub {
        $record = Example::Country->find( name => 'Argentina', name => 'Uruguay' );
    },
    'Two filters without operands produces: country_name = ? OR country_name = ?'
);

lives_ok(
    sub {
        $record = Example::Country->find( name => { ne => 'Argentina' } );
    },
    'Using not produces: country_name != ?'
);

lives_ok(
    sub {
        $record = Example::Country->find( name => { nlike => 'Argentina%' } );
    },
    'Using not with like produces: country_name NOT LIKE ?'
);

lives_ok(
    sub {
        $record = Example::Country->find( name => { nlike => '%Argentina%' } );
    },
    'Using not with like produces: country_name NOT LIKE ? and param is wrapped in %'
);


