#!perl

use lib './lib';
use strict;
use Test::More tests => 8;
use Test::Exception;
use Data::Dumper qw(Dumper);

use_ok(qw(Gideon));
use_ok(qw(Test::Gideon));

ok( Gideon->register_store( 'test', 'String!', qw/strict/ ), 'Register string store' );
is( Test::Gideon->get_store_destination(), 'destination', 'Get store destination' );
is( Test::Gideon->get_store_args(),        'String!',     'Get store args' );
is( Test::Gideon->get_store_id(),          'test',        'Get Store id' );

ok( Gideon->register_store( 'test_hash', {} ), 'Register ref store' );

dies_ok( sub { Gideon->register_store( 'test', 'String!' ) },
    'Register twice store with strict' );
