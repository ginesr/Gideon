package Test::Gideon::Results::DBI;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Carp qw(cluck);
use Gideon::Error;
use Gideon::Error::DBI;
use Moose;
use Test::MockObject;

extends 'Test::Gideon::Results';

sub connect {
    my $self = shift;
    return $self;
}

sub errstr {
    my $self = shift;
    return "This is an error"
}

sub prepare {

    my $self  = shift;
    my $query = shift;
    
    if($query =~ /insert into/i){
        return $self->prepare_to_insert();
    }

    my $session = $self->get_next_session;

    if ( !$session ) {
        Gideon::Error::DBI->throw('Session exhausted');
    }

    my $cols  = shift @{$session};
    my $sth   = Test::MockObject->new();
    my $bound = [];

    $sth->{NAME_lc} = [ map { $_ } @$cols ];
    $sth->mock(
        'execute',
        sub {
            my $class = shift;
            my @bind  = @_;
            my $total = scalar @$session;
            return $total ? $total : -1;
        }
    );
    $sth->mock(
        'bind_columns',
        sub {
            my $class = shift;
            $bound = [@_];
        }
    );
    $sth->mock(
        'fetch',
        sub {

            my $class = shift;
            my %row;
            my $c = 0;

            if ( scalar @$session == 0 ) {
                return;
            }

            my $r = shift $session;
            foreach (@$r) {
                $row{ $cols->[$c] } = $_;
                if ( ref $bound->[$c] eq 'SCALAR' ) {
                    my $bound = $bound->[$c];
                    $$bound = $_;
                }
                $c++;
            }
            return \%row;
        }
    );
    $sth->mock(
        'finish',
        sub {
            $bound = [];
        }
    );

    return $sth;
}

sub prepare_to_insert {
    
    my $self = shift;
    my $sth  = Test::MockObject->new();

    $sth->mock(
        'execute',
        sub {
            my $class = shift;
            return 1;
        }
    );

    $sth->mock(
        'finish',
        sub {
            return 1;
        }
    );
    return $sth;
}

1;
