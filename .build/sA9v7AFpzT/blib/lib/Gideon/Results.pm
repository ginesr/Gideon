
package Gideon::Results;

use strict;
use warnings;
use Class::Accessor::Fast qw(moose-like);
use Data::Dumper qw(Dumper);
use Try::Tiny;

has 'rows'      => ( is => 'rw' );
has 'sth'       => ( is => 'rw' );
has 'fields'    => ( is => 'rw' );
has 'row_index' => ( is => 'rw' );
has 'builder'   => ( is => 'rw' );
has 'columns'   => ( is => 'rw' );
has '__cache'   => ( is => 'rw' );

sub new {

    my $class = shift;
    my @args  = @_;

    my $self = {@args};
    bless $self, $class;
    $self->_init(@args);

    return $self;

}

sub size {
    my $self = shift;
    return $self->rows;
}

sub first {
    my $self = shift;
    unless ( exists $self->__cache->{0} ) {

        #row was not fetched
    }
    return $self->__cache->{0};
}

sub by_index {
    my $self = shift;
    my $ind  = shift;

    unless ( exists $self->__cache->{$ind} ) {

        #row was not fetched
    }
    return $self->__cache->{$ind};
}

sub last {
    my $self = shift;
    my $last = $self->size - 1;
    unless ( exists $self->__cache->{$last} ) {

        #row was not fetched
    }
    return $self->__cache->{$last};
}

sub next {

    my $self  = shift;
    my $index = $self->row_index;

    if ( $index > $self->rows ) {

        #end
        return undef;
    }

    unless ( exists $self->__cache->{$index} ) {
        $self->add_row_to_result();
    }

    my $row = $self->__cache->{$index}->{obj};
    $self->increment_index_count();
    return $row;

}

sub increment_index_count {
    my $self  = shift;
    my $index = $self->row_index();
    $index++;
    $self->row_index($index);
}

sub add_row_to_result {

    my $self = shift;
    my $index = $self->row_index() || 0;

    try {

        my $fetch = $self->sth->fetch;
        my $raw_data = [ map { $_ } @{$fetch} ];

        my $block = $self->builder();
        my $obj = &$block( $self->columns, $raw_data );

        $self->__cache->{$index}->{raw} = $raw_data;
        $self->__cache->{$index}->{obj} = $obj;

    }
    catch {
        warn "oh no! " . $_;
    };

}

# Private ----------------------------------------------------------------------

sub _init {

    my $self = shift;
    my $args = {@_};

    $self->row_index(0);
    $self->__cache( {} );

}

1;
