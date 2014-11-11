#!perl

use lib 'xlib';
use strict;
use Test::More tests => 20;
use Data::Dumper qw(Dumper);
use DBD::Mock;

use_ok qw(Example::Person);
use_ok qw(Example::My::Lastlog);

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement =>
          'SELECT person.person_city as `person.person_city`, person.person_country as `person.person_country`, person.person_id as `person.person_id`, person.person_name as `person.person_name`, person.person_type as `person.person_type` FROM person WHERE ( person.person_id = ? )',
        bound_params => [123],
        results      => [ [ 'person.person_id', 'person.person_country', 'person.person_name' ], [ 123, 'AR', 'Joe' ] ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

my $record = Example::Person->find( id => 123 );

is( $record->name,      'Joe', 'Original person name' );
is( $record->country,   'AR',  'Original person country' );
is( $record->id,        123,   'Original person ID' );
is( $record->type,      undef, 'Original person type' );
is( $record->city,      undef, 'Original person city' );
is( $record->is_stored, 1,     'Original person stored' );

my $clone = $record->clone;

is( $clone->name,      'Joe', 'Cloned person name' );
is( $clone->country,   'AR',  'Cloned person country' );
is( $clone->id,        undef, 'Cloned person ID gone cause is serial' );
is( $clone->type,      undef, 'Cloned person type' );
is( $clone->city,      undef, 'Cloned person city' );
is( $clone->is_stored, 0,     'Cloned person stored' );

my $new_last = Example::My::Lastlog->new( lastlog=>'2013-08-13', name => 'Somebody' );

is(ref $new_last->lastlog, 'Date::Simple', 'Check coerced is good');
is($new_last->lastlog->year,'2013','Lastlog year');

my $clone_last = $new_last->clone;

is(ref $clone_last->lastlog, 'Date::Simple', 'Check clone coerced');
is($clone_last->lastlog->year,'2013','Lastlog cloned year');

$new_last->lastlog->year(2014);

is($new_last->lastlog->year,'2014','Lastlog year changed');
is($clone_last->lastlog->year,'2013','Lastlog cloned still the same');
