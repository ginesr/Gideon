#!perl

use lib './lib';
use strict;
use Test::More tests => 6;
use Gideon;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use SQL::Abstract;

my $config_array = Gideon->validate_order_by( [ { desc => 'name' }, { asc => [ 'iso', 'name' ] } ], 'skip_meta_check' );

is( $config_array->[0]->[0]->{'-desc'},     undef, 'Order with two directions desc' );
is( $config_array->[0]->[1]->{'-asc'}->[0], undef, 'Order with two directions asc' );
is( $config_array->[0]->[1]->{'-asc'}->[1], undef, 'Order with two directions asc second argument' );

my $config_hash = Gideon->validate_order_by( { asc => [ 'iso', 'name' ], desc => 'name' }, 'skip_meta_check' );

is( $config_hash->[0]->{'-asc'}->[0],  undef, 'Order with two directions asc as hash' );
is( $config_hash->[0]->{'-asc'}->[1],  undef, 'Order with two directions asc as hash' );
is( $config_hash->[0]->{'-desc'}->[0], undef, 'Order with two directions desc as hash' );
