
package Example::Driver::MySQL;

use strict;
use warnings;
use DBI;
use Example::Error::Simple;
use Mouse;
use DBD::mysql;

extends 'Gideon::DB::Driver';

has 'db'       => ( is => 'rw', isa => 'Str', required => 1 );
has 'username' => ( is => 'rw', isa => 'Str', required => 1 );
has 'password' => ( is => 'rw', isa => 'Str' );
has 'host'     => ( is => 'rw', isa => 'Maybe[Str]' );
has 'port'     => ( is => 'rw', isa => 'Maybe[Num]' );
has 'type'     => ( is => 'ro', isa => 'Str', default  => 'MYSQL' );

my $cache_dbh;

sub connect {
    my $self = shift;

    return $cache_dbh if $cache_dbh;

    if ( my $dbh = DBI->connect( $self->connect_string, $self->username, $self->password ) ) {
        $cache_dbh = $dbh;
        return $dbh;
    }
    Example::Error::Simple->throw($DBI::errstr);
}

sub connect_string {
    
    my $self = shift;
    my $host = $self->host || '';
    my $port = $self->port || '';
    
    my $string = sprintf 'DBI:mysql:database=%s;host=%s;port=%s', $self->db, $host, $port;
    return $string;
}

1;
