#!perl

use lib 'xlib';
use strict;
use Test::More tests => 4;
use Data::Dumper qw(Dumper);
use Test::Gideon::DBI::Mock;

use_ok qw(Example::Person);

my $mock = Test::Gideon::DBI::Mock->new;
my $results = [
    {
        class   => 'Example::Person',
        ignore  => [qw(city type)],
        results => []
    }
];
$mock->mock( $results );

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $mock );

my $persons = Example::Person->find_all(
    country => 'US',
    name    => { like => 'joe' },
    {
        order_by => { desc => 'name' },
        #limit    => 10
    }
);

is( $persons->has_no_records, 1, 'Empty!' );
is( $persons->records_found,  0, 'Total results' );

