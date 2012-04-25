
package Example::Country;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Mouse;

extends 'Gideon::DBI';
store 'master:country';

has 'name' => (
    is          => 'rw',
    isa         => 'Str',
    column      => 'country_name',
    primary_key => 1,
    metaclass   => 'Gideon',
);

has 'iso' => (
    is        => 'rw',
    isa       => 'Maybe[Str]',
    column    => 'country_iso',
    metaclass => 'Gideon'
);

1;
