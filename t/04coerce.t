#!perl

use lib 'xlib';
use strict;
use Try::Tiny;
use Test::More;
use Data::Dumper qw(Dumper);
use Cwd;
use DBI;
use Test::Exception;

plan tests => 12;

use_ok(qw(Example::My::Lastlog));

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';

Gideon->register_store( 'mysql', $dbh );

my $date = Date::Simple->new( year => 2012, month => 4, day => 20 );
is( $date->year, 2012, 'Year' );

my $coerce = Example::My::Lastlog->new(
    id       => 1,
    name     => 'Foo',
    lastlog  => '2011-08-18 20:06:45',
    datetime => $date
);

is( $coerce->lastlog, '2011-08-18 20:06:45', 'Last log is a timestamp' );
is( $coerce->lastlog->year, 2011, 'Last log is coerced' );
is( $coerce->datetime->year, 2012, 'Date tame still an object' );

like( $coerce, qr/Example::My::Lastlog/, 'Class name as string' );
like( $coerce, qr/"lastlog": "2011-08-18 20:06:45"/, 'Date as json' );

my $meta_as_class = Example::My::Lastlog->metadata->get_all_meta;
my $meta_as_object = $coerce->metadata->get_all_meta;

ok($meta_as_class,'Metadata as class method');
ok($meta_as_object,'Metadata as object method');

is((scalar keys %{$meta_as_class->{attributes}}),4,'All attributes for given class');
is($meta_as_class->{attributes}->{lastlog}->{column},'timestamp','Column name for Gideon attribute');
is((not exists $meta_as_class->{attributes}->{_properties}),1,'Not a Gideon attribute');
