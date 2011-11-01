
package Gideon::DB::Driver;

use strict;
use warnings;
use Mouse;
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

1;