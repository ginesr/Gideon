#!perl

use lib 'xlib';
use strict;
use Test::More tests => 4;
use Data::Dumper qw(Dumper);
use DBD::Mock;

use_ok qw(Example::Person);
use_ok qw(Example::My::Lastlog);

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement =>
          'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( person.person_id = ? )',
        bound_params => [123],
        results      => [
            [ 'person.person_id', 'person.person_country', 'person.person_name' ],
            [ 123, 'AR', 'Joe' ] 
        ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

my $person = Example::Person->find( id => 123 );

like($person, qr/^Example::Person \(123\)/, 'Stringify class name with key');
like($person, qr/"country":"AR"/, 'Stringify JSON text');
