
package Gideon::DB::Driver;

use strict;
use warnings;
use Moose;
use DBI;
use Gideon::Error::Simple;

sub connect {
    
    my $self = shift;
    my $dbi_string = $self->get_dbi_string( $self->type() );
    
    unless ( my $dbh = DBI->connect( $dbi_string , "", "" ) ) {
        Gideon::Error::Simple->throw($DBI::errstr);
    }
    
}

sub connect_isolated {
    my $self = shift;
    Gideon::Error::Simple->throw('can\'t connect_isolated(), is not supported by your driver');
}

sub get_dbi_string {
    
    my $self = shift;
    my $type = shift;
    
    if ($type eq 'SQLITE') {
        return 'dbi:SQLite:dbname=' . $self->db;
    }
    
}

sub begin_work {
    my $self = shift;
    $self->connect_isolated->begin_work;
    return $self->isolated;
}

sub commit {
    my $self = shift;
    if (!$self->isolated) {
        warn "called commit() when no trasaction is running";
        return $self;
    }
    $self->isolated->commit;
    $self->disconnect;
}

sub rollback {
    my $self = shift;
    if (!$self->isolated) {
        warn "called rollback() when no trasaction is running";
        return $self;
    }
    $self->isolated->rollback;
    $self->disconnect;
}

__PACKAGE__->meta->make_immutable();
