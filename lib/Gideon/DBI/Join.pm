package Gideon::DBI::Join;

use strict;
use warnings;
use Gideon::DBI;
use Gideon::Error;
use Gideon::Error::DBI;
use Moose;
use Hash::Merge qw();

extends 'Gideon::DBI';

sub join_with {
    
    my $self    = shift;
    my $options = {@_};

    my $args     = $options->{args};
    my $config   = $options->{config};
    my $joins    = $options->{joins};
    my $foreings = $options->{foreings};
    
    my $foreing_class = $foreings->[0];
    
    my $tables  = $self->stores_for($foreing_class);
    my @fields  = $self->columns_meta_for($foreing_class);
    my $where   = $self->where_stmt_from_args($args);
    my $order   = $self->order_from_config($config);
    my $joined  = $self->_translate_join_sql_abstract($joins);
    my $group;

    if ( exists $config->{limit_fields} ) {
        
        @fields = $self->_filter_fields( 
            fields => \@fields, 
            filter => $config->{limit_fields}
        );
        
    }
    if ( exists $config->{grouped} ) {
        push @fields, 'count(*) as _count';
        $group = $config->{grouped};
    }

    # TODO: find relationships autmatically?
    $where = $self->_merge_where_and_join($where,$joined);   
    
    return $self->execute_and_array($tables,\@fields,$where,$order,$group);

}

sub _translate_join_sql_abstract {
    
    my $self = shift;
    my $array_ref = shift;
    my %pair = ();
    
    foreach my $hash ( @{ $array_ref } ) {
        foreach my $k ( keys %{ $hash } ) {
            if ( ref($hash->{$k}) eq 'ARRAY' ) {
                
                foreach my $f ( @{ $hash->{$k} } ) {
                    $pair{$k} = \"= $f";
                }
                next;
            }
            $pair{$k} = \"= $hash->{$k}";
        }
    }

    return \%pair;
    
}

sub _merge_where_and_join {
    
    my $self = shift;
    my $where = shift;
    my $joined = shift;
    my $final = shift;
    
    # follow SQL-Abstract "where" syntax
    # check if same exists in both hashes
    foreach ( keys %{ $joined } ) {
        if (exists $where->{$_}) {
            $final->{$_} = [ -and => {'=', $where->{$_} }, [ $joined->{$_} ] ];
            next;
        }
        $final->{$_} = $joined->{$_}
    }

    # merge
    my $merge = Hash::Merge->new()->merge($final,$where);
    return $merge;
}

sub _filter_fields {
    
    my $self = shift;
    my $params = {@_};
    
    my @fields = @{ $params->{fields} };
    
    unless (ref $params->{filter} eq 'ARRAY') {
        Gideon::Error->throw('not a valid filter list');
    }
    
    if ( my @list = @{ $params->{filter} } ) {
        my @limited;
        foreach my $f ( @list ) {
            if ( my @t = grep { /^$f\s/ } @fields ) {
                push @limited, @t;
            }
        }
        if (scalar(@limited)>0) {
            @fields = @limited;
        }
    }
    return @fields;

}

__PACKAGE__->meta->make_immutable();

1;