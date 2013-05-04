
package Gideon::DBI::Common;

use strict;
use warnings;
use Gideon::Error;
use Gideon::Error::DBI;
use Data::Dumper qw(Dumper);

sub execute_one_with_bind_columns {

    my $self  = shift;
    return $self->execute_with_bind_columns(@_, single => 1);

}

sub execute_with_bind_columns {
    
    my $self  = shift;
    my $args  = {@_};
    
    my $dbh = $args->{'dbh'} || Gideon::Error->throw('missing db handler');
    my $stmt = $args->{'query'} || '';
    my $bind = $args->{'bind'} || [];
    my $block = $args->{'block'} || sub {};
    my $only_one = $args->{'single'} || undef;
    my $debug = $args->{'debug'} || undef;

    my @bind = map { $_ } @{ $bind };
    $self->debug($debug,'Query', $stmt);
    
    my $sth = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( "failed in prepare " . $dbh->errstr );
    $self->debug($debug,'Binding',\@bind);
    
    my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( msg => "failed while executing " . ( $sth->errstr ? $sth->errstr : 'no errstr returned' ), stmt => $stmt, params => \@bind );
    my %row;

    $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) ) if @{ $sth->{NAME_lc} };

    while ( $sth->fetch ) {
        &$block(\%row);
        last if $only_one;
    }
    $sth->finish;
    
    return $rows;
    
}

sub debug {
    
    my $self = shift;
    my $flag = shift;
    my $where = shift;
    my $val = shift;
    
    return unless defined $flag;
    
    warn $where . ": " . (ref($val) ? Dumper($val) : $val);
    
}

1;