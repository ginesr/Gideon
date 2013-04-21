
package Gideon::Meta::Attribute::DBI;
 
use Moose;
use Data::Dumper qw(Dumper);
our $VERSION = '0.02';

extends 'Moose::Meta::Attribute';

has 'column' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_column',
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

package Moose::Meta::Attribute::Custom::Gideon;
sub register_implementation {'Gideon::Meta::Attribute::DBI'}

1;
