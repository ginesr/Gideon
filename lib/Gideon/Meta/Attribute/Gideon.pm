
package Gideon::Meta::Attribute::Gideon;
 
use Mouse;
 
our $VERSION = '0.02';
 
extends 'Mouse::Meta::Attribute';

has 'column' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_column',
);

package Mouse::Meta::Attribute::Custom::Gideon;
sub register_implementation {'Gideon::Meta::Attribute::Gideon'}

1;