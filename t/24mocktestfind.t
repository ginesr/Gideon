#!perl

use lib 'xlib';
use strict;
use Test::More tests => 5;
use Data::Dumper qw(Dumper);
use Test::Gideon::DBI::Mock;

use_ok qw(Example::Person);

my $mock = Test::Gideon::DBI::Mock->new;
my $results = [
    {
        class   => 'Example::Person',
        ignore  => [qw(city type)],
        results => [
            Example::Person->new( id => 1, country => 'AR', name => 'Joe Something' ),
            Example::Person->new( id => 2, country => 'UY', name => 'Joe That' ),
            Example::Person->new( id => 3, country => 'AR', name => 'Joe' ),
        ]
    },
    {
        class => 'Example::Person',
        results => []
    }
];
$mock->mock( $results );

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $mock );

my @persons = Example::Person->find_all( country => 'US', name => { like => 'joe' }, { order_by => { desc => 'name' }, limit => 10 } );

is( $persons[0]->name,    'Joe Something', 'Person 1 name using find' );
is( $persons[1]->country, 'UY',            'Person 2 country using find' );
is( $persons[2]->name,    'Joe',           'Person 3 name using find' );

