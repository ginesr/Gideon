
package Gideon::Meta::Attribute::Mongo;
 
use Moose;
our $VERSION = '0.02';

extends 'Moose::Meta::Attribute';

has 'serial' => (
    is => 'rw',
    isa => 'Bool',
    predicate => 'has_serial',
);

has 'primary_key' => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_key',
);

sub new {
    my $class = shift;
    push @_, trigger => sub { $_[0]->is_modified(1) };
    $class->SUPER::new(@_);
}

package Moose::Meta::Attribute::Custom::Gideon;
sub register_implementation {'Gideon::Meta::Attribute::Mongo'}

1;