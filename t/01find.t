#!perl

use lib 'xlib';
use strict;
use Test::More tests => 14;
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
    },
    {
        statement =>
          'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( person.person_type > ? )',
        bound_params => [0],
        results      => [],
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

is( $persons->has_no_records, 0,   'Not empty! has_no_records()' );
is( $persons->is_empty,       0,   'Not empty! is_empty()' );
is( $persons->records_found,  2,   'Total results records_found()' );
is( $persons->record_count,   2,   'Total results record_count()' );
is( $first->name,           'Foo', 'Results as object' );

$persons = Example::Person->find_all( type => { gt => 0 } );

is( $persons->has_no_records, 1, 'Is empty!' );
is( $persons->records_found,  0, 'Total results' );
