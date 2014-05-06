package Example::Virtual::Provider;

use Moose;
use warnings;
use Try::Tiny;
use Carp qw(croak);
use Data::Dumper qw(Dumper);
use Gideon::Virtual::Provider;
use Gideon::Error::Virtual;
use Gideon::DBI::Common;

extends 'Gideon::Virtual::Provider';
# externalize for easier maintenance?
virtual_store 'person_with_address' => sub {

    my $self    = shift;
    my $filters = shift;
    my $map     = shift;

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
    from gideon_virtual_person n, gideon_virtual_address a 
    where n.id = a.person_id';
    
    if (scalar @filters > 0) {
        $stmt .= ' and ';
        $stmt .= join ' and ', map { " $_ = ? " } @filters;
    }
    
    my $rows = Gideon::DBI::Common->execute_with_bind_columns(
        'dbh' => $self->dbh,
        'query' => $stmt,
        'bind' => [ @bind ],
        'block' => sub {
            
            my $row  = shift;
            my @args = $self->args_for_new_object( $package, $row );
            my $obj  = $package->new(@args);
            $obj->is_stored(1);
            
            $results->add_record($obj);
              
         }
    );
    
    return $results;

};

sub dbh {
    my $self = shift;
    my $dbh  = $self->driver->connect;
    return $dbh;
}

__PACKAGE__->meta->make_immutable();
