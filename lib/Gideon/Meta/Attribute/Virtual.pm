package Gideon::Meta::Attribute::Virtual;
 
use Moose;
our $VERSION = '0.03';

extends 'Moose::Meta::Attribute';

has 'column' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_column',
);

has 'alias' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_alias',
);

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
    my $trigger = sub { $_[0]->is_modified(1) };
    if ( grep /trigger/, @_ ) {
        my @args = @_;
        shift @args;
        my %ref = @args;
        if (my $code = $ref{trigger}) { 
            $trigger = sub { 
                $_[0]->is_modified(1);
                &$code 
            };
        }
    }
    push @_, trigger => $trigger;
    $class->SUPER::new(@_);
}

package Moose::Meta::Attribute::Custom::Gideon::Virtual;
sub register_implementation {'Gideon::Meta::Attribute::Virtual'}

1;
