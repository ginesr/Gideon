
package Gideon::DBI::Common;

use strict;
use warnings;
use Gideon::Error;

sub execute_with_bind {
    
    my $self  = shift;
    my $dbh   = shift;
    my $stmt  = shift;
    my $bind  = shift;
    my $block = shift;
    
    my @bind = map { $_ } @{ $bind };
    
    my $sth  = $dbh->prepare($stmt) or Gideon::Error->throw( $dbh->errstr );
    my $rows = $sth->execute(@bind) or Gideon::Error->throw( $dbh->errstr );
    my %row;

    $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) ) if @{ $sth->{NAME_lc} };

    while ( $sth->fetch ) {
        &$block(\%row);
    }
    $sth->finish;
    
    return;
    
}

1;