
package Gideon::DB::Driver::MySQL;

use strict;
use warnings;
use Gideon::Error;
use DBI;
use Moose;

extends 'Gideon::DB::Driver';

has 'db'          => ( is => 'rw', isa => 'Str', required => 1 );
has 'username'    => ( is => 'rw', isa => 'Str', required => 1 );
has 'raise_error' => ( is => 'rw', isa => 'Bool', default => 1 );
has 'password'    => ( is => 'rw', isa => 'Str' );
has 'host'        => ( is => 'rw', isa => 'Maybe[Str]' );
has 'port'        => ( is => 'rw', isa => 'Maybe[Num]' );
has 'type'        => ( is => 'ro', isa => 'Str', default  => 'MYSQL' );
has 'isolated'    => ( is => 'rw', isa => 'Maybe[DBI::db]' );

our $_mysql_cache_dbh = {};

sub connect {
    my $self = shift;

    if ($self->isolated) {
        return $self->isolated
    }
    if ( my $dbh = $self->is_cached ) {
        return $dbh;
    }
    if ( my $dbh = DBI->connect( $self->connect_string, $self->username, $self->password, {
        RaiseError => $self->raise_error, PrintError => 0, AutoCommit => 1
    } ) ) {
        $dbh->{'mysql_auto_reconnect'} = 1;
        $dbh->{'mysql_enable_utf8'} = 1;
        $_mysql_cache_dbh->{$self->cache_key} = $dbh;
        return $dbh;
    }
    Gideon::Error->throw($DBI::errstr);
}

sub connect_isolated {
    my $self = shift;
    
    if ($self->isolated) {
        return $self->isolated
    }

    if ( my $dbh = DBI->connect( $self->connect_string, $self->username, $self->password, {
        RaiseError => $self->raise_error, PrintError => 0, AutoCommit => 1
    } ) ) {
        $dbh->{'mysql_auto_reconnect'} = 1;
        $dbh->{'mysql_enable_utf8'} = 1;
        $self->isolated($dbh);
        return $dbh;
    }
    Gideon::Error->throw($DBI::errstr);
}

sub disconnect {
    my $self = shift;
    $self->isolated->disconnect;
    return $self->isolated(undef)
}

sub is_cached {
    my $self = shift;
    my $key = $self->cache_key;
    if ( exists $_mysql_cache_dbh->{$key} ) {
        return  $_mysql_cache_dbh->{$key};
    }
    return;
}

sub connect_string {
    
    my $self = shift;
    my $host = $self->host || '';
    my $port = $self->port || '';
    
    my $string = sprintf 'DBI:mysql:database=%s;host=%s;port=%s', $self->db, $host, $port;
    return $string;
}

sub cache_key {

    my $self = shift;
    my $host = $self->host || '';
    my $port = $self->port || '';

    my $string = sprintf 'user:%s_db:%s_host:%s_port:%s', $self->username, $self->db, $host, $port;
    return $string;
}

__PACKAGE__->meta->make_immutable();
