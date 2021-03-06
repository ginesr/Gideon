package Gideon::Extensions::Join;

use strict;
use warnings;
use Gideon::DBI::Join;
use Data::Dumper qw(Dumper);
use Try::Tiny;
use Gideon::Error;
use Carp qw(cluck croak);

sub join_with {

    my $class   = shift;
    my $package = shift;

    if ( ref($package) ) {
        Gideon::Error->throw('join_with() is a static method');
    }

    my $relations = $package->get_relations;
    my ( $args, $config ) = $package->params->decode(@_);

    if ( $relations->{params}->{type} eq 'DBI' ) {
        return $class->_execute_dbi_join( $package, $args, $config, $relations->{foreign}, $relations->{params}->{join_on} );
    }
    else {
        Gideon::Error->throw( $relations->{params}->{type} . ' not implemented' );
    }

}

sub _execute_dbi_join {

    my $class   = shift;
    my $package = shift;
    my $args    = shift;
    my $config  = shift;
    my $foreign = shift;
    my $joinon  = shift;
    
    #TODO: support multiple keys
    #TODO: check for primary keys
    
    try {

        my $foreign = $foreign;
        my $results = Gideon::DBI::Join->join_with(
            package  => $package,
            args     => $args,
            config   => $config,
            joins    => [ { $package->get_column_with_table($joinon->[0]) => $foreign->get_column_with_table($joinon->[1]) } ],
            foreigns => [$foreign]
        );

        return wantarray ? $results->flatten() : $results;

    }
    catch {
        my $e = shift;
        croak $e;
    }
    
}

1;
