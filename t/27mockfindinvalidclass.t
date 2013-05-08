#!perl

use lib 'xlib';
use strict;
use Test::More tests => 5;
use Data::Dumper qw(Dumper);
use Test::Gideon::DBI::Mock;
use Try::Tiny;
use Test::Exception;

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

try {
    Example::Person->find_all( country => 'US' );
}
catch {
    my $e = shift;
    is( ref $e, 'Gideon::Error::DBI', 'Found exception' );
    like( $e, qr/You said/, 'Error msg' );
};

throws_ok(
    sub {
        Example::Person->find_all( country => 'US' );
    },
    qr/Use Try::Tiny with this class/,
    "Can't use Test::Exception"
);
