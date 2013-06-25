#!perl

use strict;
use warnings;
use lib 'xlib';
use Test::More tests => 20;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use Test::Exception;

use_ok(qw(Example::Country));
use_ok(qw(Example::Person));

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement    => 'INSERT INTO country ( `country_iso`, `country_name`) VALUES ( ?, ? )',
        bound_params => [ undef, 'Argentina' ],
        results      => [[]]
    },
    {
        statement =>
          'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( ( person.person_country = ? AND person.person_name LIKE ? ) )',
        bound_params => [ 'US', '%joe%' ],
        results =>
          [ 
              [ 'person.person_id', 'person.person_country', 'person.person_name' ], 
              [ 1, 'AR', 'Joe Something' ], 
              [ 2, 'UY', 'Joe That' ], 
              [ 3, 'AR', 'Joe' ] 
          ]
    },
    {
        statement    => 'UPDATE person SET `person_city` = ?, `person_country` = ?, `person_id` = ?, `person_name` = ?, `person_type` = ? WHERE ( person_id = ? )',
        bound_params => [ undef, 'AR', 1, 'Bill', '', 1 ],
        results      => [[]]
    },
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

#using real db w/dbi compatible driver
#Gideon->register_store('master','DBI:mysql:database=test;host=127.0.0.1;port=3306;mysql_enable_utf8=1;mysql_auto_reconnect=1');

my $country = Example::Country->new( iso => 'AR', name => 'Argentina' );
is( $country->is_modified, 1, 'Just created' );

$country->iso(undef);

is( $country->name,        'Argentina', 'Country after name change' );
is( $country->iso,         undef,       'Clean field value' );
is( $country->is_modified, 1,           'One attribute was changed' );
is( $country->is_stored,   0,           'Is not stored yet' );

lives_ok(
    sub {
        $country->save();
    },
    'Save changes'
);

is( $country->is_modified, 0,           'Now is not modified anymore' );
is( $country->is_stored,   1,           'And is stored' );

my $persons = Example::Person->find_all( country => 'US', name => { like => '%joe%' } );
my $first_person = $persons->get_record(0); 

is( $first_person->is_modified, 0, 'From DB not changed' );
is( $first_person->is_stored, 1, 'Yes, is stored' );

is_deeply($first_person->save, undef, 'Nothing happen, havent changed');

$first_person->name('Bill');

is( $first_person->is_modified, 1, 'Trigger works' );
is( $first_person->is_stored, 1, 'Still stored' );
is( $first_person->name, 'Bill', 'The new name' );

ok($first_person->save, 'Got confirmation is stored now');

is( $first_person->is_modified, 0, 'Trigger works again' );
is( $first_person->name, 'Bill', 'Name persists' );
is( $first_person->is_modified, 0, 'Just called the method without setting a value' );
