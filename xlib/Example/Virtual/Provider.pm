
package Example::Virtual::Provider;

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Carp qw(croak);
use Data::Dumper qw(Dumper);
use Gideon::Virtual::Provider;
use Gideon::Error::Virtual;
use Gideon::DBI::Common;

extends 'Gideon::Virtual::Provider';

# externalize for easier maintenance?
my $stores = { person_with_address => 'join_person_with_address' };

sub join_person_with_address {

    my $self    = shift;
    my $filters = shift;
    
    my $package = $self->class;
    my $results = $self->results;
    
    my @filters = ();
    my @bind = ();
    
    if ($filters) {

        if ( $filters->{person_id} ) {
            push @filters, 'n.id';
            push @bind, $filters->{person_id};
        }

    }

    my $stmt = 'select n.name,n.id as person_id, a.id as address_id, a.address 
    from gideon_virtual_name n, gideon_virtual_address a where n.id = a.person_id';
    
    if (scalar @filters > 0) {
        $stmt .= ' and ';
        $stmt .= join ' and ', map { " $_ = ? " } @filters;
    }
    
    Gideon::DBI::Common->execute_with_bind(
        $self->dbh,
        $stmt,
        \@bind,
        sub {
            my $row = shift;
            my $obj = $package->new(
                person_id => $row->{'person_id'},
                name => $row->{'name'},
                address_id => $row->{'address_id'},
                address => $row->{'address'},
            );
            $obj->is_stored(1);
            $results->push( $obj );  
         }
    );
    
    return $results;

}

sub virtual_stores {
    my $self = shift;
    return $stores;
}

sub dbh {
    my $self = shift;
    my $dbh  = $self->driver->connect;
    return $dbh;
}

1;
