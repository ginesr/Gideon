
package Example::Currency;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Mouse;

extends 'Gideon::DBI';
store 'master:currency';

has 'name' => (
    is          => 'rw',
    isa         => 'Str',
    column      => 'currency_name',
    metaclass   => 'Gideon',
);

has 'symbol' => (
    is        => 'rw',
    isa       => 'Maybe[Str]',
    column    => 'currency_symbol',
    metaclass => 'Gideon'
);

1;
