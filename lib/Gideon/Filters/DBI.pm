
package Gideon::Filters::DBI;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use SQL::Abstract;

sub format {

    my $class  = shift;
    my $action = shift || 'select';
    my $table  = shift;
    my $fields = shift || {};
    my $where  = shift;
    my $order  = shift;

    my $sql = SQL::Abstract->new;
    
    if ($action eq 'select') {
        return my ( $stmt, @bind ) = $sql->select( $table, $fields, $where, $order );
    }
    else {
        return my ( $stmt, @bind ) = $sql->$action( $table, $where );
    }

}

1;
