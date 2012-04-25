#!perl

use lib './lib';
use strict;
use Test::More tests => 10;
use Data::Dumper qw(Dumper);
use DBD::Mock;

use_ok qw(Example::Person);

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement =>
          'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( ( person.person_country = ? AND person.person_name LIKE ? ) ) ORDER BY person.person_name DESC limit 10',
        bound_params => [ 'US', '%joe%' ],
        results =>
          [ [ 'person.person_id', 'person.person_country', 'person.person_name' ], [ 1, 'AR', 'Joe Something' ], [ 2, 'UY', 'Joe That' ], [ 3, 'AR', 'Joe' ], ]
    },
    {
        statement =>
          'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( person.person_id = ? )',
        bound_params => [123],
        results      => [ [ 'person.person_id', 'person.person_country', 'person.person_name' ], [ 123, 'AR', 'Joe' ] ]
    },
    {
        statement =>
          'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( person.person_country = ? ) ORDER BY person.person_name DESC limit 10',
        bound_params => ['US'],
        results      => [ [ 'person.person_id', 'person.person_country', 'person.person_name' ], [ 1, 'US', 'Foo' ], [ 2, 'US', 'Bar' ] ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

my @persons = Example::Person->find_all( country => 'US', name => { like => 'joe' }, { order_by => { desc => 'name' }, limit => 10 } );

is( $persons[0]->name,    'Joe Something', 'Person 1 name using find' );
is( $persons[1]->country, 'UY',            'Person 2 country using find' );
is( $persons[2]->name,    'Joe',           'Person 3 name using find' );

my $record = Example::Person->find( id => 123 );

is( $record->name,    'Joe', 'Person name using restore' );
is( $record->country, 'AR',  'Person country using restore' );
is( $record->id,      123,   'Person ID using restore' );

my $persons = Example::Person->find_all( country => 'US', { order_by => { desc => 'name' }, limit => 10 } );
my $first = $persons->first;

is( $persons->is_empty, 0,     'Not empty!' );
is( $persons->length,   2,     'Total results' );
is( $first->name,       'Foo', 'Results as object' );
