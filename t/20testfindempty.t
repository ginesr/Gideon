#!perl

use lib 'xlib';
use strict;
use Test::More tests => 3;
use Data::Dumper qw(Dumper);
use Test::Gideon::Results::DBI;

use_ok qw(Example::Person);

my $mock = Test::Gideon::Results::DBI->new;
$mock->mock( [ [ [ 'person.person_id', 'person.person_country', 'person.person_name' ] ] ] );

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $mock );

my $persons = Example::Person->find_all(
    country => 'US',
    name    => { like => 'joe' },
    {
        order_by => { desc => 'name' },
        limit    => 10
    }
);

is( $persons->is_empty, 1, 'Empty!' );
is( $persons->length,   0, 'Total results' );

