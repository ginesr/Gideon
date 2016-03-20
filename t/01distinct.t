#!perl

use lib 'xlib';
use strict;
use Test::More tests => 6;
use Example::Person;
use Data::Dumper qw(Dumper);
use DBD::Mock;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement =>
          'SELECT person.person_city as `person.person_city`, person.person_country as `person.person_country`, person.person_id as `person.person_id`, person.person_name as `person.person_name`, person.person_type as `person.person_type` FROM `person` WHERE ( person.person_country = ? )',
        bound_params => ['AR'],
        results      => [
            [ 'person.person_id', 'person.person_type', 'person.person_country', 'person.person_name' ],
            [ 1,                  10,                   'AR',                    'Joe Something' ],
            [ 2,                  10,                   'AR',                    'Joe That' ],
            [ 3,                  20,                   'AR',                    'Joe' ],
            [ 4,                  20,                   'AR',                    'Bud' ],
            [ 5,                  30,                   'AR',                    'Brad' ],
            [ 6,                  10,                   'AR',                    'Bill' ],
        ]
    },
    {
        statement =>
          'SELECT person.person_city as `person.person_city`, person.person_country as `person.person_country`, person.person_id as `person.person_id`, person.person_name as `person.person_name`, person.person_type as `person.person_type` FROM `person` WHERE ( person.person_country = ? )',
        bound_params => ['AR'],
        results      => [
            [ 'person.person_id', 'person.person_type', 'person.person_country', 'person.person_name' ],
            [ 1,                  10,                   'AR',                    'Joe Something' ],
            [ 2,                  10,                   'AR',                    'Joe That' ],
            [ 3,                  20,                   'AR',                    'Joe' ],
            [ 4,                  20,                   'AR',                    'Bud' ],
            [ 5,                  30,                   'AR',                    'Brad' ],
            [ 6,                  10,                   'AR',                    'Bill' ],
        ]
    },
    {
        statement =>
          'SELECT person.person_city as `person.person_city`, person.person_country as `person.person_country`, person.person_id as `person.person_id`, person.person_name as `person.person_name`, person.person_type as `person.person_type` FROM `person` WHERE ( person.person_country = ? )',
        bound_params => ['AR'],
        results      => [
            [ 'person.person_id', 'person.person_type', 'person.person_country', 'person.person_name' ],
            [ 3,                  20,                   'AR',                    'Joe' ],
            [ 3,                  20,                   'AR',                    'Joe' ],
            [ 3,                  20,                   'AR',                    'Joe' ],
            [ 3,                  20,                   'AR',                    'Joe' ],
        ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

my @results = Example::Person->find_all( country => 'AR' )->distinct('type');
is( scalar @results, 3,  'Only record with distinct type' );
is( $results[0],     10, 'Type 10 in unique' );
is( $results[1],     20, 'Type 20 in unique' );
is( $results[2],     30, 'Type 30 in unique' );

my $results = Example::Person->find_all( country => 'AR' )->distinct('type');
is( scalar @$results, 3,  'Only record with distinct type as ref' );

my @distinct = Example::Person->find_all( country => 'AR' )->distinct;
is( scalar @distinct, 1,  'Filter distinct records' );
