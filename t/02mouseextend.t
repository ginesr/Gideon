#!/usr/bin/perl

use strict;
use Test::More tests => 3;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use Example::Country;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement    => 'INSERT INTO country ( id) VALUES ( ? )',
        bound_params => [1],
        results      => []
    },
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

#using real db w/dbi compatible driver
#Gideon->register_store('master','DBI:mysql:database=test;host=127.0.0.1;port=3306;mysql_enable_utf8=1;mysql_auto_reconnect=1','root','secret');

my $country = Example::Country->new();
$country->name('Argentina');

is( $country->name, 'Argentina', 'Country' );

$country->name('Wohoo');

is( $country->name,        'Wohoo', 'Country after name change' );
is( $country->is_modified, 1,       'One attribute was changed' );

$country->save();
