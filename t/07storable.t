#!perl

use lib './lib';
use strict;
use Try::Tiny;
use Test::More tests => 4;
use Data::Dumper qw(Dumper);
use Cwd;
use Storable qw();
use Example::Driver::Storable;
use Example::Flat;
use Test::Exception;

my $dir = getcwd;
if ( $dir !~ /\/t/ ) { chdir('t') }

# Prepare test data ------------------------------------------------------------

my $table = {
    meta => { last_id => 100, last_updated => '2000-00-00' },
    data => {
        1 => { id => 1, value => 'pre generated' },
        2 => { id => 2, value => 'test' }
      }
};

Storable::store $table, 'db/flat.db';

# ------------------------------------------------------------------------------

Gideon->register_store( 'disk',
    Example::Driver::Storable->new( db => 'db/flat.db' ) );

my $flat = Example::Flat->new;
$flat->value('is a new record!');
$flat->save;

is( $flat->id, 101, 'New record' );

my $record = Example::Flat->find( value => { like => 'test' } );

is( $record->id, 2, 'Find using filters');

my $results = Example::Flat->find_all( id => { gt => 1 } );
my $rec_1 = $results->first;

is( $rec_1->value, 'test', 'Find all with filters' );

throws_ok(
    sub {

        Gideon->register_store( 'disk',
            Example::Driver::Storable->new( db => 'db/niet.db' ) );

    },
    qr/store 'disk' is already registered/,
    'Tried to register same store again'
);
