package Gideon::DBI::Results;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Try::Tiny;
use Mouse;
use Gideon::Filters::DBI;
use Gideon::Error::DBI;

has 'results' => (
    is      => 'rw',
    isa     => 'Set::Array',
    handles => {
        'first'    => 'first',
        'last'     => 'last',
        'is_empty' => 'is_empty',
        'length'   => 'length',
    }
);
has 'conn'    => ( is => 'rw', isa => 'Maybe[Str]' );
has 'where'   => ( is => 'rw', isa => 'Maybe[HashRef]' );
has 'package' => ( is => 'rw', isa => 'Str' );

sub remove {
    
    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {
        
        if ($self->results->is_empty) {
            return 0
        }

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'delete', $destination, $where );
        
        my $dbh  = $self->package->dbh($self->conn);
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $dbh->errstr );
        $sth->finish;
        
        return $rows
        
    }
    
}

sub update {

    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {
        
        if ($self->results->is_empty) {
            return 0
        }        

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'update', $destination, $args, $where );
        
        my $dbh  = $self->package->dbh($self->conn);
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $dbh->errstr );
        $sth->finish;
        
        return $rows

    }

}

__PACKAGE__->meta->make_immutable();

1;
