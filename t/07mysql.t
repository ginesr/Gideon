#!perl

use lib 'xlib';
use strict;
use Try::Tiny;
use Test::More;
use Data::Dumper qw(Dumper);
use Cwd;
use DBI;
use Test::Exception;

if ( mysql_not_installed() ) {
    plan skip_all => 'MySQL driver not installed';
}

if ( mysql_cant_connect() ) {
    plan skip_all => 'Can\'t connect to local mysql using `test` user & db';
}

plan tests => 21;

use_ok(qw(Example::Driver::MySQL));
use_ok(qw(Example::Test));
use_ok(qw(Example::TestInvalid));

# Prepare test data ------------------------------------------------------------
prepare_test_data();
# ------------------------------------------------------------------------------

my $driver = Example::Driver::MySQL->new(
    db       => 'test',
    username => 'test',
    host     => 'localhost'
);

Gideon->register_store( 'mysql_server', $driver );

my $test_data = Example::Test->find_all( undef, { limit => 5 } );
my $first     = $test_data->first;
my $last      = $test_data->last;

is( $first->name, 'rec 1', 'From mysql first record' );
is( $last->name,  'rec 5', 'From mysql last record with limit' );

my $record = Example::Test->find( id => 4 );
is( $record->name, 'rec 4', 'From mysql one record' );

throws_ok(
    sub { $record = Example::Test->find( id => 3, { conn => 'node1' } ) },
    qr/can't use node1 without pool configuration/, 'Failed to use pool here' );

my $new_rec =
  Example::Test->new( name => 'is brand new', value => 'some value' );
$new_rec->save();

is( $new_rec->id, 11, 'New record inserted' );

my $id = $new_rec->last_inserted_id();

is( $id, 11, 'Last id from db' );

throws_ok(sub { my $not_found = Example::Test->find( id => 9999 ) }, 'Gideon::Error::DBI::NotFound');

my $find_again = Example::Test->find( id => 11 );

is( $find_again->id, 11, 'Again last id from db' );
is( $find_again->name, 'is brand new', 'Again name from db' );

$find_again->name('not so new');
$find_again->save();

is( $find_again->id, 11, 'Again after save' );

my $test_all = Example::Test->find_all;
my $hash = $test_all->as_hash('id');

is( $hash->{1}->id, 1, 'From hash id 1' );
is( $hash->{2}->value, 'value of 2', 'From hash value 2' );
is( $hash->{3}->name, 'rec 3', 'From hash name 3' );

dies_ok(sub{my $invalid = Example::TestInvalid->find_all},'Invalid class attribute');

my $all = Example::Test->find_all;
is($all->record_count,11,'All count');

my $no_result = Example::Test->find_all(name=>'foo');
is($no_result->record_count,0,'No results using find_all()');

throws_ok(sub { Example::Test->find(name=>'foo') },'Gideon::Error::DBI::NotFound','No results exception using find()');
throws_ok(sub { Example::Test->find(name=>'foo') },qr/no results found Example::Test/,'No results text');

# Auxiliary test functions -----------------------------------------------------

sub prepare_test_data {

    #standard mysql install has test db and test user, try to use that
    my $dbh = DBI->connect( "dbi:mysql:database=test;host=;port=", "test", "" );

    my $create_t1 =
qq~create table gideon_t1 (id int not null auto_increment, name varchar(20), value text, primary key (id), key (name))~;

    $dbh->do('drop table if exists gideon_t1');
    $dbh->do($create_t1);

    for ( 1 .. 10 ) {
        $dbh->do( "insert into gideon_t1 (name,value) values(?,?)",
            undef, "rec $_", "value of $_" );
    }

}

sub mysql_not_installed {
    try { use DBD::mysql; return undef }
    catch { return 1 }
}

sub mysql_cant_connect {
    
    my $test_db = 'database=test;host=;port=';
    my $test_user = 'test';
    my $test_pass = '';
    
    if ($ENV{'GIDEON_DBI_TEST_DB'}) {
        $test_db = $ENV{GIDEON_DBI_TEST_DB}; 
    }
    if ($ENV{'GIDEON_DBI_TEST_USER'}) {
        $test_user = $ENV{GIDEON_DBI_TEST_USER}; 
    }
    if ($ENV{'GIDEON_DBI_TEST_PASS'}) {
        $test_user = $ENV{GIDEON_DBI_TEST_PASS}; 
    }
    
    try { DBI->connect( "dbi:mysql:$test_db", $test_user, $test_pass ) or die; return undef }
    catch { return 1 }
}
