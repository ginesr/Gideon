package Example::My::Person;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Mouse;
use Try::Tiny;
use Carp qw(croak);
use Data::Dumper qw(Dumper);

extends 'Gideon::DBI';
store 'mysql_master:gideon_j1';

has 'id' => (
    is          => 'rw',
    isa         => 'Num',
    column      => 'id',
    serial      => 1,
    primary_key => 1,
    metaclass   => 'Gideon'
);

has 'name' => (
    is        => 'rw',
    required  => 1,
    isa       => 'Str',
    column    => 'name',
    metaclass => 'Gideon'
);

sub find_by_address {
    
    my $class = shift;
    
    my ( $args, $config ) = $class->decode_params(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    try {

        my $results = $class->join_with( 
            args     => $args,
            config   => $config,
            joins    => [{ 
                $class->get_column_with_table('id') => Example::My::Address->get_column_with_table('person_id')
            }],
            foreings => [ 'Example::My::Address' ]
        );
        
        return wantarray ? $results->flatten() : $results;
        
    }
    catch {
        my $e = shift;
        croak $e;
    }
    
}

1;