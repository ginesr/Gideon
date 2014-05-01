package Gideon::DBI::Join;

use Moose;
use Gideon::DBI;
use Gideon::Error;
use Gideon::Error::DBI;
use Hash::Merge qw();
use Data::Dumper qw(Dumper);

sub join_with {
    
    my $self    = shift;
    my $options = {@_};

    my $package  = $options->{package};
    my $args     = $options->{args};
    my $config   = $options->{config};
    my $joins    = $options->{joins};
    my $foreigns = $options->{foreigns};

    my $foreign_class = $foreigns->[0];
    
    my $tables  = $package->stores_for_foreign($foreign_class);   
    my @fields  = $package->columns_meta_for_foreign($foreign_class);
    my $where   = $package->where_stmt_from_args($args);
    my $order   = $package->order_from_config($config);
    my $joined  = $package->_translate_join_sql_abstract($joins);
    my $group;

    if ( exists $config->{limit_fields} ) {
        
        @fields = $package->_filter_fields( 
            fields => \@fields, 
            filter => $config->{limit_fields}
        );
        
    }
    if ( exists $config->{grouped} ) {
        push @fields, 'count(*) as _count';
        $group = $config->{grouped};
    }
    # TODO: find relationships autmatically?
    my $merged = $self->_merge_where_and_join($where,$joined);
    return $package->execute_and_array($tables,\@fields,$merged,$order,$group);
    
}

sub _merge_where_and_join {
    
    my $self = shift;
    my $where = shift;
    my $joined = shift;

    my $final = {};
    
    # follow SQL-Abstract "where" syntax
    # check if same exists in both hashes

    foreach ( keys %{ $joined } ) {
        if (exists $where->{$_}) {
            $final->{$_} = [ -and => {'=', $where->{$_} }, [ $joined->{$_} ] ];
            delete $where->{$_};
            next;
        }
        $final->{$_} = $joined->{$_}
    }

    # merge
    return Hash::Merge->new()->merge($final,$where);
}

__PACKAGE__->meta->make_immutable();
