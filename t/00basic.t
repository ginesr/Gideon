#!perl

use lib 'xlib';
use strict;
use Test::More tests => 16;
use Test::Exception;
use Data::Dumper qw(Dumper);

use_ok(qw(Gideon));
use_ok(qw(Basic::Gideon));
use_ok(qw(Basic::Foo));
use_ok(qw(Basic::Bar));

my $foo = Basic::Foo->new;

ok( Gideon->register_store( 'test', 'String!', qw/strict/ ), 'Register string store' );

is( Basic::Foo->storage->origin,    'bar',         'Get store origin as class' );
is( $foo->storage->origin,          'bar',         'Get store origin as blessed' );
is( Basic::Gideon->storage->origin, 'destination', 'Get store origin other class' );
is( Basic::Gideon->storage->args,   'String!',     'Get store args' );
is( Basic::Gideon->storage->id,     'test',        'Get Store id' );

ok( Gideon->register_store( 'test_hash', {} ), 'Register ref store' );

dies_ok( sub { Basic::Bar->storage->args },
    'Store not registered just yet' );

dies_ok( sub { Gideon->register_store( 'test', 'String!' ) },
    'Register twice store with strict' );

dies_ok( sub { Gideon->storage->origin },
    'origin() Must be called from subclass' );

dies_ok( sub { Gideon->storage->args },
    'args() Must be called from subclass' );

is(Gideon->storage->by_name_get_args('test'), 'String!', 'Called by name');