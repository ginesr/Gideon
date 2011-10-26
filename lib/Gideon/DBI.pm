
package Gideon::DBI;

use strict;
use warnings;
use base 'Gideon';
use Class::Accessor::Fast qw(moose-like);
use Gideon::Error;
use SQL::Abstract;
use Try::Tiny;
use Data::Dumper qw(Dumper);
use Gideon::Results;

has '__dbh'    => ( is => 'rw' );
has '__stored' => ( is => 'rw' );

my $_custom_handler;

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

        my ( $stmt, @bind ) = $sql->select( $class->get_table_from_meta(), $fields, \%where, \@order );

        my $sth  = $class->dbh->prepare($stmt) or die $class->dbh->errstr;
        my $rows = $sth->execute(@bind)        or die $class->dbh->errstr;
        my %row;

        $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) );
        $sth->fetch;
        $sth->finish;

        my $args_map       = $class->map_meta_with_row( \%row );
        my @construct_args = $class->args_with_db_values( $args_map, \%row );
        my $obj            = $class->new( __stored => 1, @construct_args );

    }
    catch {
        warn "oh no! " . $_;
        return undef;
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

        my ( $stmt, @bind ) = $sql->select( $class->get_table_from_meta(), $fields, \%where, \@order );

        my $sth  = $class->dbh->prepare($stmt) or die $class->dbh->errstr;
        my $rows = $sth->execute(@bind)        or die $class->dbh->errstr;
        my %row;

        $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) );

        my $results  = Collections::Ordered->new;
        my $args_map = $class->map_meta_with_row( \%row );

        while ( $sth->fetch ) {
            my @construct_args = $class->args_with_db_values( $args_map, \%row );
            my $obj = $class->new( __stored => 1, @construct_args );
            $results->add($obj);
        }
        $sth->finish;

        return wantarray ? $results->to_array() : $results;

    }
    catch {
        warn "oh no! " . $_;
        return undef;
    };

}

sub insert { }

sub dbh {

    my $self = shift;

    if ( ref($self) and defined $self->__dbh() ) {
        return $self->__dbh;
    }

    if ($_custom_handler) {
        my $dbh = &$_custom_handler;
        return $dbh;
    }

    my $dbh = $self->handler;
    $self->__dbh($dbh);
    return $dbh;

}

sub handler {
    Gideon::Error->throw('handelr must be defined in your DBI class');
}

sub register_handler {

    my $class = shift;
    my $code  = shift;

    $_custom_handler = $code;

}

# Private ----------------------------------------------------------------------

sub args_with_db_values {

    my $class          = shift;
    my $construct_args = shift;
    my $row            = shift;

    return map { $_ => $row->{ $construct_args->{$_} } } ( keys %{$construct_args} );

}

1;
