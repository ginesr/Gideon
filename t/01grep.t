#!perl

use lib 'xlib';
use strict;
use Test::More tests => 1;
use Example::Person;
use Data::Dumper qw(Dumper);
use DBD::Mock;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement =>
          'SELECT person.person_country as `person.person_country`, person.person_city as `person.person_city`, person.person_name as `person.person_name`, person.person_type as `person.person_type`, person.person_id as `person.person_id` FROM person WHERE ( person.person_country = ? )',
        bound_params => [ 'AR' ],
        results => [ 
          [ 'person.person_id', 'person.person_type', 'person.person_country', 'person.person_name' ], 
          [ 1, 10, 'AR', 'Joe Something' ], 
          [ 2, 10, 'AR', 'Joe That' ], 
          [ 3, 20, 'AR', 'Joe' ],
          [ 4, 20, 'AR', 'Bud' ],
          [ 5, 30, 'AR', 'Brad' ], 
        ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

my $results = Example::Person->find_all( country => 'AR' )->grep( sub { $_->type >= 30 } );
is($results->records_found, 1, 'Only record one after grep');
