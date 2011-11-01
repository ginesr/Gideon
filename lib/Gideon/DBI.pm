
package Gideon::DBI;

use strict;
use warnings;
use Gideon::Error;
use Gideon::Error::Simple;
use SQL::Abstract;
use Try::Tiny;
use DBI;
use Carp qw(cluck);
use Data::Dumper qw(Dumper);
use Gideon::Results;
use Mouse;
use Set::Array;

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

        if ( scalar( keys %{$fields} ) == 0 ) {
            Gideon::Error->throw('can\'t delete without table primary key');
        }

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
        if ( ref $_ eq 'Gideon::Error' ) {
            die $_;
        }
        warn 'oh no!! ' . Dumper($_);
    };

}

sub save {

    my $self = shift;

    unless ( ref($self) ) {
        Gideon::Error->throw('save() is not a static method');
    }

    return undef if ( $self->is_stored and not $self->is_modified );

    try {

        my $dbh    = $self->dbh;
        my $sql    = SQL::Abstract->new;
        my $table  = $self->get_store_destination();
        my $fields = $self->get_columns_hash();

        unless ( $self->is_stored ) {

            # remove auto increment columns for insert
            $self->remove_auto_columns_for_insert($fields);
        }

        my %data = map { $fields->{$_} => $self->$_ } sort keys %{$fields};
        my $stmt = '';
        my @bind = ();

        if ( $self->is_stored ) {
            ( $stmt, @bind ) = $sql->update( $table, \%data );
        } else {
            ( $stmt, @bind ) = $sql->insert( $table, \%data );
        }

        my $sth  = $self->dbh->prepare($stmt) or die $self->dbh->errstr;
        my $rows = $sth->execute(@bind)       or die $self->dbh->errstr;
        $sth->finish;

        if ( my $serial = $self->get_serial_columns_hash ) {
            my $last_id = $self->last_inserted_id;
            my $serial_attribute = ( map { $_ } keys %{$serial} )[0];
            $self->$serial_attribute($last_id);
        }

        $self->is_stored(1);
        $self->is_modified(0);

        return;

    }
    catch {
        warn 'oh no!! ' . $_;
        return $_;
    };

}

sub last_inserted_id {

    my $self = shift;
    my $sth  = $self->dbh->prepare('select last_insert_id() as last') or die $self->dbh->errstr;
    my $rows = $sth->execute or die $self->dbh->errstr;
    my %row;

    $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) );
    $sth->fetch;
    $sth->finish;

    return $row{'last'};

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
        my %where  = $class->add_table_to_where( ( map { $_ => $args->{ $map->{$_} } } ( sort keys %{$map} ) ) );
        my $order  = $config->{order_by} || [];

        my ( $stmt, @bind ) = $sql->select( $class->get_store_destination(), $fields, \%where, $class->add_table_to_order($order) );

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
        cluck $_;
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
        my %where  = $class->add_table_to_where( ( map { $_ => $args->{ $map->{$_} } } ( sort keys %{$map} ) ) );
        my $order  = $config->{order_by} || [];

        my ( $stmt, @bind ) = $sql->select( $class->get_store_destination(), $fields, \%where, $class->add_table_to_order($order) );

        my $sth  = $class->dbh->prepare($stmt) or die $class->dbh->errstr;
        my $rows = $sth->execute(@bind)        or die $class->dbh->errstr;
        my %row;

        $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) );

        my $results  = Set::Array->new;
        my $args_map = $class->map_meta_with_row( \%row );

        while ( $sth->fetch ) {
            my @construct_args = $class->args_with_db_values( $args_map, \%row );
            my $obj = $class->new(@construct_args);
            $obj->is_stored(1);
            $results->push($obj);
        }
        $sth->finish;

        return wantarray ? $results->flatten() : $results;

    }
    catch {
        cluck $_;
        return $_;
    };

}

sub add_table_to_order {

    my $class = shift;
    my $table = $class->get_store_destination();
    my $sort  = shift;

    if ( ref($sort) eq 'ARRAY' ) {
        foreach my $clauses ( @{$sort} ) {
            if ( ref($clauses) eq 'HASH' ) {
                foreach ( keys %{$clauses} ) {
                    $clauses->{$_} = $table . '.' . $clauses->{$_};
                }
            }
            else {
                $clauses = $table . '.' . $clauses;
            }
        }
    }
    unless ( ref($sort) ) {
        $sort = $table . '.' . $sort;
    }

    return $sort;
}

sub add_table_to_where {

    my $class = shift;
    my $table = $class->get_store_destination();
    my %where = @_;

    return map { $table . '.' . $_ => $where{$_} } sort keys %where;
}

sub get_columns_from_meta {

    my $class = shift;
    my $table = $class->get_store_destination();

    my $columns = $class->SUPER::get_columns_from_meta();
    my @columns = map { $table . '.' . $_ . ' as `' . $table . '.' . $_ . '`' } @{$columns};

    return wantarray ? @columns : \@columns;
}

sub map_meta_with_row {

    my $class = shift;
    my $row   = shift;
    my $map   = {};

    foreach my $r ( keys %{$row} ) {
        my ( $table, $col ) = split( /\./, $r );
        my $attribute = $class->get_attribute_for_column($col);
        $map->{$attribute} = $r;
    }

    return $map;

}

sub dbh {

    my $self = shift;

    if ( ref($self) and defined $self->__dbh() ) {
        return $self->__dbh;
    }

    return $self->_from_store_dbh();

}

sub lt {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub gt {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub gte {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub lte {
    my $class = shift;
    my $string = shift || "";
    return $string;
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

    if ( ref( $args->[0] ) and $args->[0]->can('connect') ) {
        my $dbh = $args->[0]->connect();
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

sub remove_auto_columns_for_insert {

    my $self  = shift;
    my $field = shift;

    my $serial = $self->get_serial_columns_hash;

    foreach ( keys %{$serial} ) {
        delete $field->{$_};
    }

}

sub args_with_db_values {

    my $class          = shift;
    my $construct_args = shift;
    my $row            = shift;

    return map { $_ => $row->{ $construct_args->{$_} } } ( keys %{$construct_args} );

}

1;
