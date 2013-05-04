package Gideon::Virtual::Results;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Try::Tiny;
use Moose;
use Gideon::Error;
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
has 'package' => ( is => 'rw', isa => 'Str' );

sub first {
    my $self = shift;
    return $self->get_record(0)
}
sub last {
    my $self = shift;
    return $self->get_record(-1)
}

sub map {

    my $self = shift;
    my $code = shift;
    
    unless ( ref($code) ) {
        Gideon::Error->throw('grep() needs a fuction as argument');
    }
    if ( ref($code) ne 'CODE' ) {
        Gideon::Error->throw('grep() argument is not a function reference');
    }
        
    my @filter = grep { defined $_ } map { (&$code) ? $_ : undef } $self->records;
    my $results = __PACKAGE__->new(
        'package' => $self->package,
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
        'package' => $self->package,
    );
    $results->results(\@filter);
    return $results;
}

sub remove {
    
    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {
        
        if ($self->has_no_records) {
            return 0
        }

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        # implement remove
        
    }
    
}

sub update {

    my $self = shift;
    my ( $args, $config ) = $self->package->decode_params(@_);

    try {
        
        if ($self->has_no_records) {
            return 0
        }        

        my $where       = $self->where;
        my $destination = $self->package->get_store_destination();

        # implement update

    }

}

__PACKAGE__->meta->make_immutable();
