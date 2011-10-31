
package Example::Error::Simple;

use strict;
use warnings;
use Carp qw(cluck carp croak);

our $ERROR_DEBUG = 0;

sub throw {

    my $class = shift;
    my $msg   = shift;

    my ( $pkg, $file, $line ) = caller(1);

    if ($ERROR_DEBUG) {

        carp "ERROR THROWN IN: $pkg ($msg) Line: $line\n";
        cluck 'STACKTRACE';

    }

    my $self = { pkg => $pkg, msg => $msg };
    bless $self, $class;

    croak $self;

}

1;
