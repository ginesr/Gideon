
package Gideon::Filters::DBI;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use SQL::Abstract;

use constant MYSQL_ESCAPE => '`';

sub format {

    my $class  = shift;
    my $action = shift || 'select';
    my $table  = shift;
    my $fields = shift || [];
    my $where  = shift;
    my $order  = shift;
    my $limit  = shift || '';

    $table =  MYSQL_ESCAPE . $table . MYSQL_ESCAPE;

    my ($sql,@bind) = $class->build_statment($action,$table,$fields,$where,$order);

    $sql = $class->add_limit_in_sql($sql,$limit);

    return wantarray ? ($sql,@bind) : $sql;

}

sub build_statment {

    my ($class,$action,$table,$fields,$where,$order) = @_;
    my $sql = SQL::Abstract->new;

    if ( $action eq 'select' ) {
        return my ( $stmt, @bind ) =
          $sql->select( $table, $fields, $where, $order );
    }
    else {
        $fields = $class->escape_field_names($fields);
        return my ( $stmt, @bind ) = $sql->$action( $table, $fields, $where );
    }

}

sub add_limit_in_sql {

    my $class = shift;
    my $stmt  = shift;
    my $limit = shift;

    if ($limit) {
        return $stmt . ' limit ' . $limit;
    }
    return $stmt;
}

sub escape_field_names {
    my $class = shift;
    my $fields  = shift;
    foreach (keys %{$fields}) {
        my $mylsq_escaped = join '.', map { MYSQL_ESCAPE . $_ . MYSQL_ESCAPE } split /\./, $_;
        $fields->{$mylsq_escaped} = $fields->{$_};
        delete $fields->{$_};
    }
    return $fields;
}

1;
