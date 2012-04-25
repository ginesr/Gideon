#!perl

use strict;
use warnings;
use lib './lib';
use Test::More tests => 13;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use Test::Exception;

use_ok qw(Example::Person);
use_ok qw(Example::Country);
use_ok qw(Example::Currency);

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement =>
'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( ( person.person_country = ? AND person.person_id = ? ) )',
        bound_params => [ 'AR', 123 ],
        results      => [
            [
                'person.person_id',   'person.person_name',
                'person.person_city', 'person.person_country',
                'person.person_type'
            ],
            [ 123, 'Foo', 'Vegas', 'AR', 300 ]
        ]
    },
    {
        statement    => 'DELETE FROM person WHERE ( person_id = ? )',
        bound_params => [123],
        results      => []
    },
    {
        statement =>
'SELECT currency.currency_symbol as `currency.currency_symbol`, currency.currency_name as `currency.currency_name` FROM currency WHERE ( currency.currency_name = ? )',
        bound_params => ['Dollar'],
        results      => [
            [ 'currency.currency_name', 'currency.currency_symbol' ],
            [ 'Dollar',                 'USD' ]
        ]
    },
    {
        statement =>
          'DELETE FROM person WHERE ( person.person_country = ? ) limit 10',
        bound_params => ['AR'],
        results      => [ [], [], [] ],
    },
    {
        statement =>
          'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( person.person_country = ? )',
        bound_params => ['AR'],
        results      => [ 
        [ 'person.person_id', 'person.person_country', 'person.person_name' ], 
        [ 1, 'AR', 'Foo' ], 
        [ 2, 'AR', 'Bar' ], 
        ]
    },
    {
        statement => 'DELETE FROM person WHERE ( person.person_country = ? )',
        bound_params => ['AR'],
        results => [[],[],[]],
    },
    {
        statement => 'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( ( person.person_country = ? AND person.person_type > ? ) )',
        bound_params => ['AR',30],
        results => [ [ 'person.person_id', 'person.person_country', 'person.person_name' ], 
        [ 1, 'AR', 'Foo' ], 
        [ 2, 'AR', 'Bar' ], 
        ]
    },
    {
        statement => 'DELETE FROM person WHERE ( ( person.person_country = ? AND person.person_type > ? ) )',
        bound_params => ['AR',30],
        results => [ [],[],[],[] ],
    },
    {
        statement => 'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( person.person_type = ? )',
        bound_params => [30],
        results => []
    },    
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

#using real db w/dbi compatible driver
#Gideon->register_store('master','DBI:mysql:database=test;host=127.0.0.1;port=3306;mysql_enable_utf8=1;mysql_auto_reconnect=1');

my $record = Example::Person->find( id => 123, country => 'AR' );

is( $record->name,    'Foo', 'Person name using restore' );
is( $record->country, 'AR',  'Person country using restore' );
is( $record->id,      123,   'Person ID using restore' );

lives_ok(
    sub {
        $record->remove;
    },
    'Remove record'
);

throws_ok(
    sub {
        my $record = Example::Currency->find( name => 'Dollar' );
        $record->remove;
    },
    'Gideon::Error',
    'Can\'t delete without keys'
);

my $rows_deleted = Example::Person->remove( country => 'AR', { limit => 10 } );
is( $rows_deleted, 2, 'Remove all records matching criteria' );

throws_ok(
    sub {
        my $rec = Example::Currency->new;
        $rec->remove_all( name => 'Dollar' );
    },
    'Gideon::Error',
    'Can\'t call remove all as instance method'
);

my $rows = Example::Person->find_all( country => 'AR' )->remove();
is( $rows, 2, 'Two row removed from results' );

$rows = Example::Person->find_all( country => 'AR', type => { gt => 30 } )->remove();
is( $rows, 3, 'Two arguments remove within results' );

$rows = Example::Person->find_all( type => 30 )->remove();
is( $rows, 0, 'Nothing to delete' );
