package Example::My::Person;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Meta::Attribute::DBI;
use Mouse;
use Try::Tiny;
use Carp qw(croak);

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
        
        my $tables = $class->stores_for('Example::My::Address');
        
        my $fields = [ 'gideon_j1.id', 'gideon_j1.name','gideon_j2.id',
        'gideon_j2.person_id','gideon_j2.address' ];
        
        my $where = {
            'gideon_j1.id' => $args->{person_id},
            'gideon_j2.person_id' => \'= gideon_j1.id',
        };
        
        my $order = ['gideon_j2.id'];

        my $results = $class->execute_and_array($tables,$fields,$where,$order);
        return $results;
        
    }
    catch {
        my $e = shift;
        croak $e;
    }
    
}

1;