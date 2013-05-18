
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

sub get_dbi_string {
    
    my $self = shift;
    my $type = shift;
    
    if ($type eq 'SQLITE') {
        return 'dbi:SQLite:dbname=' . $self->db;
    }
    
}

sub begin_work {
    my $self = shift;
    $self->connect->begin_work;
}

sub commit {
    my $self = shift;
    $self->connect->commit;
}

sub rollback {
    my $self = shift;
    $self->connect->rollback;
}

__PACKAGE__->meta->make_immutable();
