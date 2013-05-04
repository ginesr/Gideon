
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
has 'stmt' => ( is => 'rw', isa => 'Maybe[Str]' );
has 'params' => ( is => 'rw', isa => 'Maybe[Arrayref]' );

sub throw {
    
    my $class = shift;
    my $msg;
    my $stmt;
    my $params;
    
    if (scalar @_ == 1) {
        $msg = shift;
    }
    else {
        my $args = {@_};
        
        $msg = $args->{msg};
        $stmt = $args->{stmt};
        $params = $args->{params};
    }
    
    my ( $pkg, $file, $line ) = caller(1);
    
    if ( $ERROR_DEBUG ) {

        carp "ERROR THROWN IN: $pkg ($msg) Line: $line\n";
        cluck 'STACKTRACE';

    }

    my $self = { pkg => $pkg, msg => $msg, stmt => $stmt, params => $params  };
    bless $self, $class;
    croak $self;
    
}

sub msg {
    return shift->{msg}
}

sub stringify {
    my $self = shift;
    my $text = $self->msg || '';
    return $text . "\n" . '';
}

1;