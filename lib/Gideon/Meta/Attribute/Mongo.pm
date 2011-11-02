
package Gideon::Meta::Attribute::Mongo;
 
use Mouse;
our $VERSION = '0.02';

extends 'Mouse::Meta::Attribute';

has 'primary_key' => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_key',
);

package Mouse::Meta::Attribute::Custom::Gideon;
sub register_implementation {'Gideon::Meta::Attribute::Mongo'}

1;