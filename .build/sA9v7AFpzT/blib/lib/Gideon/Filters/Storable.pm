
package Gideon::Filters::Storable;

use strict;
use warnings;
use Data::Dumper qw(Dumper);

sub format {

    my $class   = shift;
    my $filters = shift;

    foreach my $f ( %{$filters} ) {
        if (ref($filters->{$f}) eq 'HASH') {
            $class->_transform_from_hash( $f, $filters);
        } 
    }

    return $filters;

}

sub _transform_from_hash {
    
    my $class = shift;
    my $field = shift;
    my $filters = shift;
    
    foreach my $t (keys %{ $filters->{$field} }) {
        if ($t eq '-like') {
            $filters->{$field} = $filters->{$field}->{$t};
        }
        if ($t eq '>') {
            $filters->{$field} = [ '>', $filters->{$field}->{$t} ];
        }
        if ($t eq '>=') {
            $filters->{$field} = [ '>=', $filters->{$field}->{$t} ];
        }
        if ($t eq '<=') {
            $filters->{$field} = [ '<=', $filters->{$field}->{$t} ];
        }
        if ($t eq '<') {
            $filters->{$field} = [ '<', $filters->{$field}->{$t} ];
        }
        if ($t eq '!') {
            $filters->{$field} = [ '!', $filters->{$field}->{$t} ];
        }
    }
    
    return $filters;
}


1;