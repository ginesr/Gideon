#!/usr/bin/perl

use lib './lib/';
use strict;
use Test::More tests => 5;
use Data::Dumper qw(Dumper);
use Test::MockObject;

use_ok('Gideon');
use_ok('Test::Gideon');

ok( Gideon->register_store( 'test', 'String!' ), 'Register string store' );
is( Test::Gideon->get_store_destination(), 'destination', 'Get store destination' );
is( Test::Gideon->get_store_args(), 'String!', 'Get store args' );
