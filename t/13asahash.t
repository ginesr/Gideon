#!perl

use strict;
use warnings;
use lib 'xlib';
use Test::More tests => 2;
use Data::Dumper qw(Dumper);
use Example::Country;
use Test::Exception;

my $country = Example::Country->new( iso => 'AR', name => 'Argentina' );
my $as_hash = $country->as_hash;

is( $as_hash->{iso},  'AR',        'Country code' );
is( $as_hash->{name}, 'Argentina', 'Country name' );
