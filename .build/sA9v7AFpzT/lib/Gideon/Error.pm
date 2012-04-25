
package Gideon::Error;

use strict;
use warnings;
use Carp qw(cluck carp croak);
use Class::Accessor::Fast qw(antlers);
use overload '""' => \&stringify, fallback => 1;

our $ERROR_DEBUG = 0;
our $VERSION = '0.02';

has 'msg' => ( is => 'rw', isa => 'Str' );
has 'pkg' => ( is => 'rw', isa => 'Str' );

sub throw {
    
    my $class = shift;
    my $msg = shift;
    
    my ( $pkg, $file, $line ) = caller(1);
    
    if ( $ERROR_DEBUG ) {

        carp "ERROR THROWN IN: $pkg ($msg) Line: $line\n";
        cluck 'STACKTRACE';

    }

    my $self = { pkg => $pkg, msg => $msg  };
    bless $self, $class;
    
    croak $self;
    
}

sub msg {
    return shift->{msg}
}

sub stringify {
    my $self = shift;
    my $text = $self->msg;
    return $text . "\n" . '';
}

1;