package Test::Gideon::Results;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Carp qw(cluck);
use Gideon::Error;
use Moose;

our $VERSION = '0.02';
$VERSION = eval $VERSION;

has 'session'       => ( is => 'rw', isa => 'ArrayRef' );
has 'destroyerrstr' => ( is => 'rw', isa => 'Str' );
has 'sessionerrors' => ( is => 'rw', isa => 'Num', default => 0 );

sub mock {
    my $self = shift;
    my $session = shift || [];
    $self->session($session);
}

sub get_next_session {
    my $self    = shift;
    my $session = $self->session;
    my $next    = shift @{$session};
    $self->session($session);
    return $next;
}

sub count_left {
    my $self    = shift;
    my $session = $self->session;
    return scalar @{$session};
}

DESTROY {
    my $self    = shift;
    my $session = $self->session;
    if (my $errcount = $self->sessionerrors) {
        Gideon::Error->throw("\nSession ended with errors ($errcount session not found)");
    }
    unless ($session) {
        return;
    }
    if ( my $rest = scalar @{$session} > 0 ) {
        Gideon::Error->throw("Session not exhausted ($rest left)");
    }
}

1;
