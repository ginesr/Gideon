
package Gideon::Meta::Attribute::DBI;
 
use Mouse;
our $VERSION = '0.02';

extends 'Mouse::Meta::Attribute';

has 'column' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_column',
);

has 'primary_key' => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_key',
);

package Mouse::Meta::Attribute::Custom::Gideon;
sub register_implementation {'Gideon::Meta::Attribute::DBI'}

1;