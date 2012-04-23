
=head1 NAME

Gideon Connection Pool

=head1 DESCRIPTION

Map connections to more than one host

=cut 

package Gideon::Connection::Pool;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Gideon::Error;
use Mouse;
use Hash::MultiValue;
use 5.008_001;

our $VERSION = '0.02';
$VERSION = eval $VERSION;

has 'pool' => (
    is      => 'rw',
    isa     => 'Hash::MultiValue',
    default => sub { Hash::MultiValue->new },
    lazy    => 1
);

sub get {
    my $self = shift;
    my $key = shift;
    if ( $self->detect($key) ) {
        my $hash = $self->pool;
        return $hash->{$key}
    }
    Gideon::Error->throw('called get() using a reference') if ref $key;
    Gideon::Error->throw('called get() without key') unless $key;
    Gideon::Error->throw($key . ' is not in the pool');
}

sub detect {
    my $self = shift;
    my $key = shift;
    my $hash = $self->pool;
    
    if (exists $hash->{$key}) {
        return 1;
    }
    
    return;
}

sub push {

    my $self = shift;
    my $key  = shift;
    my $conn = shift;

    my $hash = $self->pool;
    $hash->{$key} = $conn;
    
    return;

}

__PACKAGE__->meta->make_immutable();

1;
