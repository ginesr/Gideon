package Test::Gideon::Results::DBI;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Carp qw(cluck);
use Gideon::Error;
use Gideon::Error::DBI;
use Moose;
use Test::MockObject;
use Test::More;

extends 'Test::Gideon::Results';

my $times = 0;

sub connect {
    my $self = shift;
    return $self;
}

sub errstr {
    my $self = shift;
    return "This is an error";
}

sub get_info {
    my $self = shift;
    return;
}

sub prepare {

    my $self  = shift;
    my $query = shift;

    my $session = $self->get_next_session;
    $times ++;

    subtest __PACKAGE__ . " - Subtest $times passed" => sub { 
        plan tests => 3;
        
        my $result = 0;
        my $msg = 'found session';
        my $left = $self->count_left;
        
        if ($session and scalar @{$session} >= 0) {
           $result = scalar @{$session} - 1;
        }
        else {
            $msg = 'session not found';
            $result = -1;
            $self->sessionerrors( $self->sessionerrors + 1 );
        }
        
        ok( $query, 'query: ' . substr( $query, 0, 50 ) . ' ...' );
        ok( 1, "$msg results ($result)" );
        ok( 1, "sessions left $left");
        
    };

    if ( $query =~ /insert into/i ) {
        return $self->prepare_to_insert();
    }

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
            if ( scalar(@$r) != scalar(@$cols) ) {
                print STDERR "Invalid result, colums mismatch\n";
                die;
            }
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
