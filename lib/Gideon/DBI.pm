
package Gideon::DBI;

use strict;
use warnings;
use Gideon::Error;
use Gideon::Error::Simple;
use SQL::Abstract;
use Try::Tiny;
use DBI;
use Data::Dumper qw(Dumper);
use Gideon::Results;
use Mouse;
use Collections::Ordered;

our $VERSION = '0.02';

extends 'Gideon';

has '__dbh' => ( is => 'rw' );

sub remove {

    my $self = shift;

    unless ( ref($self) ) {
        Gideon::Error->throw('save() is not a static method');
    }

    return undef unless $self->is_stored;

    try {

        my $dbh    = $self->dbh;
        my $sql    = SQL::Abstract->new;
        my $table  = $self->get_store_destination();
        my $fields = $self->get_key_columns_hash();
        my %where = map { $fields->{$_} => $self->$_ } sort keys %{$fields};

        my ( $stmt, @bind ) = $sql->delete( $table, \%where );

        my $sth  = $self->dbh->prepare($stmt) or die $self->dbh->errstr;
        my $rows = $sth->execute(@bind)       or die $self->dbh->errstr;
        $sth->finish;

        $self->is_stored(0);
        $self->is_modified(0);

        return;

    }
    catch {
        warn 'oh no!! ' . $_;
        return $_;
    };

}

sub save {

    my $self = shift;

    unless ( ref($self) ) {
        Gideon::Error->throw('save() is not a static method');
    }

    return undef unless $self->is_modified;

    try {

        my $dbh    = $self->dbh;
        my $sql    = SQL::Abstract->new;
        my $table  = $self->get_store_destination();
        my $fields = $self->get_columns_hash();
        my %data   = map { $fields->{$_} => $self->$_ } sort keys %{$fields};
        my $stmt   = '';
        my @bind   = ();

        if ( $self->is_stored ) {
            ( $stmt, @bind ) = $sql->update( $table, \%data );
        } else {
            ( $stmt, @bind ) = $sql->insert( $table, \%data );
        }

        my $sth  = $self->dbh->prepare($stmt) or die $self->dbh->errstr;
        my $rows = $sth->execute(@bind)       or die $self->dbh->errstr;
        $sth->finish;

        $self->is_stored(1);
        $self->is_modified(0);

        return;

    }
    catch {
        warn 'oh no!! ' . $_;
        return $_;
    };

}

sub find {

    my $class = shift;
    my ( $args, $config ) = $class->decode_params(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    try {

        my $sql = SQL::Abstract->new;

        my $fields = $class->get_columns_from_meta();
        my $map    = $class->map_args_with_meta($args);
        my %where  = ( map { $_ => $args->{ $map->{$_} } } ( sort keys %{$map} ) );
        my @order  = ();

        my ( $stmt, @bind ) = $sql->select( $class->get_store_destination(), $fields, \%where, \@order );

        my $sth  = $class->dbh->prepare($stmt) or die $class->dbh->errstr;
        my $rows = $sth->execute(@bind)        or die $class->dbh->errstr;
        my %row;

        $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) );
        $sth->fetch;
        $sth->finish;

        my $args_map       = $class->map_meta_with_row( \%row );
        my @construct_args = $class->args_with_db_values( $args_map, \%row );
        my $obj            = $class->new(@construct_args);
        $obj->is_stored(1);
        return $obj;

    }
    catch {
        warn "oh no! " . $_;
        return $_;
    };

}

sub find_all {

    my $class = shift;
    my ( $args, $config ) = $class->decode_params(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    $args = $class->filter_rules($args);

    try {

        my $sql = SQL::Abstract->new;

        my $fields = $class->get_columns_from_meta();
        my $map    = $class->map_args_with_meta($args);
        my %where  = ( map { $_ => $args->{ $map->{$_} } } ( sort keys %{$map} ) );
        my @order  = ();

        my ( $stmt, @bind ) = $sql->select( $class->get_store_destination(), $fields, \%where, \@order );

        my $sth  = $class->dbh->prepare($stmt) or die $class->dbh->errstr;
        my $rows = $sth->execute(@bind)        or die $class->dbh->errstr;
        my %row;

        $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) );

        my $results  = Collections::Ordered->new;
        my $args_map = $class->map_meta_with_row( \%row );

        while ( $sth->fetch ) {
            my @construct_args = $class->args_with_db_values( $args_map, \%row );
            my $obj = $class->new(@construct_args);
            $obj->is_stored(1);
            $results->add($obj);
        }
        $sth->finish;

        return wantarray ? $results->to_array() : $results;

    }
    catch {
        warn "oh no! " . $_;
        return $_;
    };

}

sub dbh {

    my $self = shift;

    if ( ref($self) and defined $self->__dbh() ) {
        return $self->__dbh;
    }

    return $self->_from_store_dbh();

}

# Private ----------------------------------------------------------------------

sub _from_store_dbh {

    my $self = shift;

    if ( ref($self) and defined $self->__dbh() ) { return $self->__dbh() }

    my $dbh;
    my $args = $self->get_store_args();

    if ( ref( $args->[0] ) eq 'DBI::db' ) {
        $dbh = $args->[0];
        return $dbh;
    }

    my $dbi_string = $args->[0];
    my $user       = $args->[1];
    my $pw         = $args->[2];

    unless ( $dbh = DBI->connect( $dbi_string, $user, $pw, { RaiseError => 1 } ) ) {
        Gideon::Error::Simple->throw($DBI::errstr);
    }

    $self->__dbh($dbh);
    return $dbh;
}

sub args_with_db_values {

    my $class          = shift;
    my $construct_args = shift;
    my $row            = shift;

    return map { $_ => $row->{ $construct_args->{$_} } } ( keys %{$construct_args} );

}

1;
