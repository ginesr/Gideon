#!perl

use lib 'xlib';
use strict;
use Test::More tests => 9;
use Data::Dumper qw(Dumper);
use Test::Gideon::Results::DBI;

use_ok qw(Example::Person);

my $mock = Test::Gideon::Results::DBI->new;
$mock->mock([
    [
        [ 'person.person_id', 'person.person_country', 'person.person_name' ], 
        [ 1, 'AR', 'Joe Something' ], 
        [ 2, 'UY', 'Joe That' ], 
        [ 3, 'AR', 'Joe' ]
    ],
    [ 
        [ 'person.person_id', 'person.person_country', 'person.person_name' ], 
        [ 123, 'AR', 'Joe' ] 
    ]
]);

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $mock );

my @persons = Example::Person->find_all( country => 'US', name => { like => 'joe' }, { order_by => { desc => 'name' } } );

is( $persons[0]->name,    'Joe Something', 'Person 1 name using find' );
is( $persons[1]->country, 'UY',            'Person 2 country using find' );
is( $persons[2]->name,    'Joe',           'Person 3 name using find' );

my $record = Example::Person->find( id => 123 );

is( $record->name,    'Joe', 'Person name using restore' );
is( $record->country, 'AR',  'Person country using restore' );
is( $record->id,      123,   'Person ID using restore' );
