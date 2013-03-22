#!perl

use lib 'xlib';
use strict;
use Test::More tests => 6;
use Data::Dumper qw(Dumper);
use Test::Gideon::Results::DBI;
use Test::Exception;

use_ok qw(Example::Country);

my $mock = Test::Gideon::Results::DBI->new;
Gideon->register_store( 'master', $mock );

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
