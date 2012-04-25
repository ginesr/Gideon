#!perl

use strict;
use warnings;
use lib 'xlib';
use Test::More tests => 10;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use Example::Country;
use Test::Exception;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement    => 'INSERT INTO country ( country_iso, country_name) VALUES ( ?, ? )',
        bound_params => [ 'AR', 'Wohoo' ],
        results      => []
    },
    {
        statement    => 'UPDATE country SET country_iso = ?, country_name = ? WHERE ( country_name = ? )',
        bound_params => [ 'AR', 'Argentina', 'Argentina'],
        results      => []
    }
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

#using real db w/dbi compatible driver
#Gideon->register_store('master','DBI:mysql:database=test;host=127.0.0.1;port=3306;mysql_enable_utf8=1;mysql_auto_reconnect=1','root','secret');

my $country = Example::Country->new( iso => 'AR' );
$country->name('Argentina');

is( $country->name, 'Argentina', 'Country' );

$country->name('Wohoo');

is( $country->name,        'Wohoo', 'Country after name change' );
is( $country->is_modified, 1,       'One attribute was changed' );
is( $country->is_stored,   0,       'Is not stored yet' );

lives_ok(
    sub {
        $country->save();
    },
    'Save changes'
);

is( $country->is_stored,   1,     'Reset stored flag' );
is( $country->is_modified, 0,     'Reset modified flag' );
is( $country->save,        undef, 'Not doing anything' );

$country->name('Argentina');

lives_ok(
    sub {
        $country->save();
    },
    'Update changes'
);

throws_ok(
    sub {
        Example::Country->save();
    },
    'Gideon::Error',
    'Can\'t call save without new instance'
);
