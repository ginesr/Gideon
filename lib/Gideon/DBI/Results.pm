package Gideon::DBI::Results;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Try::Tiny;
use Moose;
use Gideon::Filters::DBI;
use Gideon::Error::DBI;
use List::MoreUtils qw(uniq);

with 'Gideon::Results';

sub remove {

    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {

        if ( $self->has_no_records ) {
            return 0;
        }

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'delete', $destination, $where );

        my $dbh  = $self->package->dbh( $self->conn );
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

        if ( $self->has_no_records ) {
            return 0;
        }

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'update', $destination, $args, $where );

        my $dbh  = $self->package->dbh( $self->conn );
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $dbh->errstr );
        $sth->finish;

        return $rows

    }

}

__PACKAGE__->meta->make_immutable();
