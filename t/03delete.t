#!perl

use strict;
use warnings;
use lib './lib';
use Test::More tests => 8;
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
            [ 'person.person_id', 'person.person_name', 'person.person_city', 'person.person_country', 'person.person_type' ],
            [ 123, 'Foo', 'Vegas', 'AR', 300 ]
        ]
    },
    {
        statement    => 'DELETE FROM person WHERE ( person_id = ? )',
        bound_params => [123],
        results      => []
    },
    {
        statement    => 'SELECT currency.currency_symbol as `currency.currency_symbol`, currency.currency_name as `currency.currency_name` FROM currency WHERE ( currency.currency_name = ? )',
        bound_params => ['Dollar'],
        results      => [ [ 'currency.currency_name', 'currency.currency_symbol' ], [ 'Dollar', 'USD' ] ]
    }
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

