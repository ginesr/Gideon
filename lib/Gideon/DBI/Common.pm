
package Gideon::DBI::Common;

use strict;
use warnings;
use Gideon::Error;
use Gideon::Error::DBI;

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
    
    my @bind = map { $_ } @{ $bind };
    
    my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
    my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $dbh->errstr );
    my %row;

    $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) ) if @{ $sth->{NAME_lc} };

    while ( $sth->fetch ) {
        &$block(\%row);
        last if $only_one;
    }
    $sth->finish;
    
    return $rows;
    
}

1;