package Gideon::DBI::Results;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Try::Tiny;
use Moose;
use Gideon::Filters::DBI;
use Gideon::Error::DBI;
use List::MoreUtils qw(uniq);

has 'results' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    handles => {
        has_no_records => 'is_empty',
        filter_records => 'grep',
        clear_results  => 'clear',
        count_records  => 'count',        
        uniq_records   => 'uniq',
        sort_records   => 'sort',
        find_record    => 'first',
        map_records    => 'map',
        records_found  => 'count',
        add_record     => 'push',
        get_record     => 'get',
        records        => 'elements',
    },
    lazy => 1,
    default => sub { return [] }
);
has 'conn'    => ( is => 'rw', isa => 'Maybe[Str]' );
has 'where'   => ( is => 'rw', isa => 'Maybe[HashRef]' );
has 'package' => ( is => 'rw', isa => 'Str' );

sub first {
    my $self = shift;
    return $self->get_record(0)
}
sub last {
    my $self = shift;
    return $self->get_record(-1)
}

sub distinct {

    my $self     = shift;
    my $property = shift;
    
    if ($property) {
        # TODO: validate property
        return $self->distinct_property($property)
    }
    
    my @uniq = $self->uniq_records;
    
    my $results = __PACKAGE__->new(
        'where'   => $self->where,
        'package' => $self->package,
        'conn'    => $self->conn,
    );
    $results->results(\@uniq);

    return $results;    
    
}

sub distinct_property {
    my $self     = shift;
    my $property = shift;
    my @filtered = ();

    foreach my $i ( $self->records ) {
        if ( $i->can($property) ) {
            push @filtered, $i->$property;
        }
        else {
            Gideon::Error->throw("object can't $property");
        }
    }
    my @uniq = uniq @filtered;
    return wantarray ? @uniq : [@uniq];    
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

    my @filter = grep { defined $_ } map { (&$code) ? $_ : undef } $self->records;

    my $results = __PACKAGE__->new(
        'where'   => $self->where,
        'package' => $self->package,
        'conn'    => $self->conn,
    );
    $results->results(\@filter);
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

    my @filter = grep { &$code } $self->records;

    my $results = __PACKAGE__->new(
        'where'   => $self->where,
        'package' => $self->package,
        'conn'    => $self->conn,
    );
    $results->results(\@filter);
    return $results;
}

sub remove {

    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {

        if ( $self->has_no_records ) {
            return 0;
        }

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'delete', $destination, $where );

        my $dbh  = $self->package->dbh( $self->conn );
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

        if ( $self->has_no_records ) {
            return 0;
        }

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'update', $destination, $args, $where );

        my $dbh  = $self->package->dbh( $self->conn );
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $dbh->errstr );
        $sth->finish;

        return $rows

    }

}

sub as_hash {

    my $self = shift;
    my $key = shift || Gideon::Error::DBI->throw('provide a key to return a hash');

    my @list = $self->results->flatten();
    my $hash = {};

    foreach my $i (@list) {
        $hash->{ $i->$key } = $i;
    }

    return $hash;
}

__PACKAGE__->meta->make_immutable();
