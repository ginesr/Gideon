#!perl

use lib 'xlib';
use strict;
use Test::More tests => 4;
use Data::Dumper qw(Dumper);
use Test::Gideon::DBI::Mock;
use Test::Try;

use_ok qw(Example::Person);
use_ok qw(Example::Country);

my $mock    = Test::Gideon::DBI::Mock->new;
my $results = [
    {
        class   => 'Example::Country',
        results => []
    }
];
$mock->mock($results);

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $mock );

throws_ok(
    sub {
        Example::Person->find_all( country => 'US' );
    },
    qr/You said/,
    "Invalid Class"
);

throws_ok(
    sub {
        Example::Person->find_all( country => 'US' );
    },
    'Gideon::Error::DBI',
    "Class missing"
);
