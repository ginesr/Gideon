package Gideon::DBI::Results;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Try::Tiny;
use Moose;
use Gideon::Filters::DBI;
use Gideon::Error::DBI;
use Set::Array;

has 'results' => (
    is      => 'rw',
    isa     => 'Set::Array',
    handles => {
        'first'    => 'first',
        'last'     => 'last',
        'is_empty' => 'is_empty',
        'length'   => 'length',
        'flatten'  => 'flatten',
    }
);
has 'conn'    => ( is => 'rw', isa => 'Maybe[Str]' );
has 'where'   => ( is => 'rw', isa => 'Maybe[HashRef]' );
has 'package' => ( is => 'rw', isa => 'Str' );

sub distinct {
    
    my $self = shift;
    my $property = shift;
    my @list = $self->results->flatten();
    my $filtered = Set::Array->new;
    
    foreach my $i (@list) {
        if ($i->can($property)) {
            $filtered->push($i->$property);
        }
        else {
            Gideon::Error->throw("object can't $property");
        }
    }
    return $filtered->unique
}

sub map {

    my $self = shift;
    my $code = shift;
    
    unless ( ref($code) ) {
        Gideon::Error->throw('map() needs a fuction as argument');
    }
    if ( ref($code) ne 'CODE' ) {
        Gideon::Error->throw('map() argument is not a function reference');
    }
        
    my $filtered = Set::Array->new;
    
    my @list = $self->results->flatten();
    my @filter = grep { defined $_ } map { (&$code) ? $_ : undef } @list;
    
    $filtered->push(@filter);
    
    my $results = __PACKAGE__->new(
        'where'   => $self->where,
        'package' => $self->package,
        'conn'    => $self->conn,
        'results' => $filtered 
    );
    
    return $results;
    
}

sub grep {
    
    my $self = shift;
    my $code = shift;
    
    unless ( ref($code) ) {
        Gideon::Error->throw('grep() needs a fuction as argument');
    }
    if ( ref($code) ne 'CODE' ) {
        Gideon::Error->throw('grep() argument is not a function reference');
    }
        
    my $filtered = Set::Array->new;
    
    my @list = $self->results->flatten();
    my @filter = grep { &$code } @list;
    
    $filtered->push(@filter);
    
    my $results = __PACKAGE__->new(
        'where'   => $self->where,
        'package' => $self->package,
        'conn'    => $self->conn,
        'results' => $filtered 
    );
    
    return $results;
    
}

sub remove {
    
    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {
        
        if ($self->results->is_empty) {
            return 0
        }

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'delete', $destination, $where );
        
        my $dbh  = $self->package->dbh($self->conn);
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $dbh->errstr );
        $sth->finish;
        
        return $rows
        
    }
    
}

sub update {

    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {
        
        if ($self->results->is_empty) {
            return 0
        }        

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'update', $destination, $args, $where );
        
        my $dbh  = $self->package->dbh($self->conn);
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $dbh->errstr );
        $sth->finish;
        
        return $rows

    }

}

__PACKAGE__->meta->make_immutable();
