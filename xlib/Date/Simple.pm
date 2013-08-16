package Date::Simple;

use strict;
use base qw(Class::Accessor::Fast);
use overload '""' => \&to_string, 'bool' => \&is_void, fallback => 1;

__PACKAGE__->mk_accessors(qw(year month day hour min sec));

sub new {

    my $class = shift;
    return bless {@_}, $class;

}

sub clone {
    my $self = shift;
    return __PACKAGE__->new(
            year     => $self->year,
            month    => $self->month,
            day      => $self->day,
    )
}

sub from_mysql_string {

    my $self       = shift;
    my $mysql_date = shift;
    
    unless ($mysql_date) {
        return $self->new(
            year     => 0,
            month    => 0,
            day      => 0,
        );        
    }

    my ( $date, $time ) = split( ' ', $mysql_date );
    my ( $year, $month, $day ) = split( '-', $date );

    if ($time) {

        my ( $hour, $min, $sec ) = split( ':', $time );
        
        return $self->new(
            year     => $year,
            month    => $month + 0,
            day      => $day + 0,
            hour     => $hour + 0,
            min      => $min + 0,
            sec      => $sec + 0,
        );

    }

    $month += 0 if $month;
    $day   += 0 if $day;

    return $self->new(
        year     => $year,
        month    => $month,
        day      => $day,
    );
    
}

sub to_string {

    my $self = shift;
    
    if ($self->hour and $self->min and $self->sec) {
        return sprintf '%04d-%02d-%02d %02d:%02d:%02d', $self->year, $self->month, $self->day, $self->hour, $self->min, $self->sec;        
    }
    if (!$self->year and !$self->month and !$self->day) {
        return undef
    }
    
    return sprintf '%04d-%02d-%02d', $self->year, $self->month, $self->day;

}

sub is_void {
    my $self = shift;
    if (!$self->year and !$self->mon and !$self->day) {
        return 0
    }
    return 1;
}

1;