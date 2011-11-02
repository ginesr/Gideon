#!/usr/bin/perl

use lib '.lib/';
use strict;
use Test::More;
use Data::Dumper qw(Dumper);

if ( mongo_installed() ) {
    plan skip_all => 'MongoDB module not installed';
} else {
    plan tests => 3;
}

use Mongo::Person;
use MongoDB;

# Prepare test data ------------------------------------------------------------

my $conn    = MongoDB::Connection->new;
my $db      = $conn->gideon;
my $persons = $db->person;

$persons->drop;
$persons->insert( { id => 1, name => 'Joe', city => 'Dallas', country => 'US', type => '20' } );

# END Prepare test data --------------------------------------------------------

Gideon->register_store( 'gideon', MongoDB::Connection->new );

my $persons = Mongo::Person->find_all( country => 'US', { order_by => { desc => 'name' }, limit => 10 } );
my $first = $persons->first;

is( $persons->is_empty, 0,     'Not empty!' );
is( $persons->length,   1,     'Total results' );
is( $first->name,       'Joe', 'Results as object' );

sub mongo_installed {

    try { use MongoDB; return undef }
    catch { return 1 };

}
