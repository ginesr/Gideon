
package Gideon::Filters::Mongo;

use strict;
use warnings;
use Data::Dumper qw(Dumper);

sub format {

    my $class   = shift;
    my $filters = shift;

    foreach my $f ( %{$filters} ) {
        if (ref($filters->{$f}) eq 'HASH') {
            foreach my $t (keys %{ $filters->{$f} }) {
                if ($t eq '-like') {
                    $filters->{$f} = $filters->{$f}->{$t};
                }
            }
        } 
    }

    return $filters;

}

1;
