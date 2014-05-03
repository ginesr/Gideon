package Gideon::DBI::Results;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Try::Tiny;
use Moose;
use Gideon::Filters::DBI;
use Gideon::Error::DBI;
use Gideon::Error::DBI::Results;
use List::MoreUtils qw(uniq);

with 'Gideon::Results';

sub remove {

    my $self = shift;
    my ( $args, $config ) = $self->package->params->decode(@_);

    try {

        if ( $self->has_no_records ) {
            return 0;
        }

        my $where  = $self->where;
        my $origin = $self->package->storage->origin();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'delete', $origin, $where );

        my $dbh  = $self->package->dbh( $self->conn );
        my $sth  = $dbh->prepare_cached($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $sth->errstr );
        $sth->finish;

        return $rows

    }
    catch {
        my $e = shift;
        Gideon::Error::DBI::Results->throw($e);
    };

}

sub update {

    my $self = shift;
    my ( $args, $config ) = $self->package->params->decode(@_);

    try {

        if ( $self->has_no_records ) {
            return 0;
        }

        my $where  = $self->where;
        my $origin = $self->package->storage->origin();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'update', $origin, $args, $where );

        my $dbh  = $self->package->dbh( $self->conn );
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $sth->errstr );
        $sth->finish;

        return $rows

    }
    catch {
        my $e = shift;
        Gideon::Error::DBI::Results->throw($e);
    };
}

__PACKAGE__->meta->make_immutable();
