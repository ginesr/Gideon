#!perl

use lib './lib';
use strict;
use Test::More tests => 6;
use Data::Dumper qw(Dumper);

use_ok(qw(Gideon));
use_ok(qw(Test::Gideon));

ok( Gideon->register_store( 'test', 'String!' ), 'Register string store' );
is( Test::Gideon->get_store_destination(),
    'destination', 'Get store destination' );
is( Test::Gideon->get_store_args(), 'String!', 'Get store args' );
is( Test::Gideon->get_store_id(),   'test',    'Get Store id' );
