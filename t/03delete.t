#!/usr/bin/perl

use strict;
use Test::More tests => 5;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use Example::Person;
use Example::Country;
use Test::Exception;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement => 'SELECT person_country, person_city, person_name, person_type, person_id FROM person WHERE ( ( person_country = ? AND person_id = ? ) )',
        bound_params => [ 'AR', 123 ],
        results      => [
            [ 'person_id', 'person_name', 'person_city', 'person_country', 'person_type' ],
            [ 123,         'Foo',         'Vegas',       'AR',             300 ]
        ]
    },
    {
        statement    => 'DELETE FROM person WHERE ( person_id = ? )',
        bound_params => [ 123 ],
        results      => []
    },
    {
        statement    => 'SELECT country_iso, country_name FROM country WHERE ( country_iso = ? )',
        bound_params => [ 'UY' ],
        results      => [
            [ 'country_iso','country_name' ],
            [ 'UY', 'Uruguay' ]
        ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

#using real db w/dbi compatible driver
#Gideon->register_store('master','DBI:mysql:database=test;host=127.0.0.1;port=3306;mysql_enable_utf8=1;mysql_auto_reconnect=1','root','secret');

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
        my $record = Example::Country->find( iso => 'UY' );
        $record->remove;
    },
    'Gideon::Error',
    'Can\'t delete without keys'
);

