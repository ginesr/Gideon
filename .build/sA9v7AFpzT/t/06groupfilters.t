#!perl

use lib 'xlib';
use strict;
use Test::More tests => 4;
use Gideon;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use SQL::Abstract;

my ( $args, $config ) = Gideon->decode_params(
    foo  => { not  => 'bar' },                    # produces and ...
    name => { like => 'that', not => 'this' },    # produces "and" ..
    name => { lt   => 1 }                         # ends with "or"
);

$args = Gideon->filter_rules( $args, 'skip_meta_check' );

my $sql    = SQL::Abstract->new();
my $fields = ['test'];
my ( $stmt, @bind ) = $sql->select( 'blah', $fields, $args );

is( $args->{'name'}->[0]->{'-like'}, '%that%', 'nested and with or, AND part 1' );
is( $args->{'name'}->[0]->{'!'},     '<>this', 'nested and with or, AND part 2' );
is( $args->{'name'}->[1]->{'<'},     '<1',     'nested and with or, OR part 3' );
is( $args->{'foo'}->{'!'},           '<>bar',  'not filter' );
