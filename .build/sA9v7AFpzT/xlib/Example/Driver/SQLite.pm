
package Example::Driver::SQLite;

use strict;
use warnings;
use DBI;
use Example::Error::Simple;
use Mouse;
use DBD::SQLite;

extends 'Gideon::DB::Driver';

has 'db'   => ( is => 'rw', isa => 'Str', required => 1 );
has 'type' => ( is => 'ro', isa => 'Str', default  => 'SQLITE' );

sub connect {
    my $self = shift;
    unless ( my $dbh = DBI->connect( "dbi:SQLite:dbname=" . $self->db , "", "" ) ) {
        Example::Error::Simple->throw($DBI::errstr);
    }
}

1;
