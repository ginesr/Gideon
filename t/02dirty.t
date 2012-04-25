#!perl

use strict;
use warnings;
use lib './lib';
use Test::More tests => 5;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use Example::Country;
use Test::Exception;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement    => 'INSERT INTO country ( country_iso, country_name) VALUES ( ?, ? )',
        bound_params => [ undef, 'Argentina' ],
        results      => []
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

#using real db w/dbi compatible driver
#Gideon->register_store('master','DBI:mysql:database=test;host=127.0.0.1;port=3306;mysql_enable_utf8=1;mysql_auto_reconnect=1');

my $country = Example::Country->new( iso => 'AR', name => 'Argentina' );
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
