
package Gideon::Error;

use strict;
use warnings;
use Carp qw(cluck carp croak);

our $ERROR_DEBUG = 0;

sub throw {
    
    my $self = shift;
    my $msg = shift;
    
    my ( $pkg, $file, $line ) = caller(1);
    
    if ( $ERROR_DEBUG ) {

        carp "ERROR THROWN IN: $pkg ($msg) Line: $line\n";
        cluck 'STACKTRACE';

    }
    
    croak "Exception: " . $pkg . " - " . $msg;
    
}

1;