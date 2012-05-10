package Example::My::Lastlog;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Moose;
use Moose::Util::TypeConstraints;
use Date::Simple;

extends 'Gideon::DBI';
store 'mysql:gideon_t3';

subtype 'MySQLdateStringToDate', as 'Date::Simple'; 
coerce 'MySQLdateStringToDate', from 'Str', via { Date::Simple->from_mysql_string($_) };

has 'id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);

has 'name' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'name',
    metaclass => 'Gideon'
);

has 'lastlog' => (
    is        => 'rw',
    required  => 1,
    isa       => 'MySQLdateStringToDate',
    column    => 'timestamp',
    metaclass => 'Gideon',
    coerce    => 1
);

__PACKAGE__->meta->make_immutable();

1;