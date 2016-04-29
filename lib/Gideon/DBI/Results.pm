package Gideon::DBI::Results;

use Moose;
use Try::Tiny;
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
            $self->changed(0);
            return $self;
        }

        my $where  = $self->where;
        my $origin = $self->package->storage->origin();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'delete', $origin, $where );

        my $dbh  = $self->package->dbh( $self->conn );
        my $sth  = $dbh->prepare_cached($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $sth->errstr );
        $sth->finish;

        if ( Gideon->cache->is_registered ) {
            Gideon->cache->clear($self->package);
        }
        $self->changed($rows);
        my $fields = $self->package->metadata->get_key_columns_hash();
        foreach my $r ($self->records){
            foreach (keys %{$fields}) {
                $self->package->track_delete_action($r->$_);
            }
        }
        return $self

    } catch {
        my $e = shift;
        Gideon::Error::DBI::Results->throw($e);
    }
}

sub update {

    my $self = shift;
    my ( $args, $config ) = $self->package->params->decode(@_);

    try {

        if ( $self->has_no_records ) {
            $self->changed(0);
            return $self;
        }

        my $where  = $self->where;
        my $origin = $self->package->storage->origin();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'update', $origin, $args, $where );

        my $dbh  = $self->package->dbh( $self->conn );
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $sth->errstr );
        $sth->finish;

        if ( Gideon->cache->is_registered ) {
            Gideon->cache->clear($self->package);
        }
        $self->changed($rows);
        my $fields = $self->package->metadata->get_key_columns_hash();
        foreach my $r ($self->records){
            foreach (keys %{$fields}) {
                $self->package->track_update_action($r->$_);
            }
        }
        return $self

    } catch {
        my $e = shift;
        Gideon::Error::DBI::Results->throw($e);
    }
}

__PACKAGE__->meta->make_immutable();
no Moose;
1;