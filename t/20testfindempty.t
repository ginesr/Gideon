#!perl

use lib 'xlib';
use strict;
use Test::More tests => 4;
use Data::Dumper qw(Dumper);
use Test::Gideon::Results::DBI;

use_ok qw(Example::Person);

my $mock = Test::Gideon::Results::DBI->new;
$mock->mock( [[]] );

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

