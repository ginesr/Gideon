#!perl

use lib 'xlib';
use strict;
use Test::More tests => 9;
use Data::Dumper qw(Dumper);
use Test::Gideon::DBI::Mock;
use Test::Try;

use_ok qw(Example::Country);

my $mock = Test::Gideon::DBI::Mock->new;
my $results = [
    {
        class   => 'Example::Country',
        ignore  => [],
        results => []
    }
];
$mock->mock( $results );

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

is( $country->is_stored,   1,       'Now it is' );
is( $country->is_modified, 0,       'Reset modified flag' );
