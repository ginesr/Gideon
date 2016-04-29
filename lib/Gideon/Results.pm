package Gideon::Results;

use strict;
use warnings;
use Moose::Role;
use Try::Tiny;
use List::MoreUtils qw(uniq);
use Gideon::Error::DBI;

has 'results' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    handles => {
        has_no_records => 'is_empty',
        is_empty       => 'is_empty',
        filter_records => 'grep',
        clear_results  => 'clear',
        count_records  => 'count',
        uniq_records   => 'uniq',
        sort_records   => 'sort',
        find_record    => 'first',
        map_records    => 'map',
        records_found  => 'count',
        record_count   => 'count',
        shift_record   => 'shift',
        add_record     => 'push',
        get_record     => 'get',
        records        => 'elements',
    },
    lazy => 1,
    default => sub { return [] }
);
has 'package' => ( is => 'rw', isa => 'Str' );
has 'conn'    => ( is => 'rw', isa => 'Maybe[Str]' );
has 'where'   => ( is => 'rw' );
has 'total'   => ( is => 'rw', isa => 'Num' );
has 'changed' => ( is => 'rw', isa => 'Num' );

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
    my $pkg = ref $self;
    my $results = $pkg->new(
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
    my $pkg = ref $self;
    my $results = $pkg->new(
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
    my $pkg = ref $self;
    my $results = $pkg->new(
        'where'   => $self->where,
        'package' => $self->package,
        'conn'    => $self->conn,
    );
    $results->results(\@filter);
    return $results;
}

sub as_hash {

    my $self = shift;
    my $key = shift || Gideon::Error::DBI->throw('provide a key to return a hash');

    my @list = $self->records;
    my $hash = {};

    foreach my $i (@list) {
        $hash->{ $i->$key } = $i;
    }

    return $hash;
}

sub update {}
sub remove {}

1;
