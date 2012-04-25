#!perl

use strict;
use warnings;
use lib 'xlib';
use Test::More tests => 2;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use Example::Person;
use Test::Exception;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement    => 'INSERT INTO person ( person_city, person_country, person_name, person_type) VALUES ( ?, ?, ?, ? )',
        bound_params => [ 'Dallas', 'US', 'John Doe', 100 ],
        results      => []
    },
    {
        statement    => 'select last_insert_id() as last',
        bound_params => [],
        results      => [ ['last'], [99] ]
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

#using real db w/dbi compatible driver
#Gideon->register_store('master','DBI:mysql:database=test;host=127.0.0.1;port=3306;mysql_enable_utf8=1;mysql_auto_reconnect=1');

my $person = Example::Person->new( name => 'John Doe', city => 'Dallas', country => 'US', type => 100 );

lives_ok(
    sub {
        $person->save();
    },
    'Save record'
);

is( $person->id, 99, 'Auto increment for new records' );
