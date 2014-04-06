package Gideon::Mongo;

use strict;
use warnings;
use Gideon::Error;
use Gideon::Error::Simple;
use MongoDB;
use Try::Tiny;
use Carp qw(cluck croak);
use Data::Dumper qw(Dumper);
use Moose;
use Gideon::Mongo::Results;
use Gideon::Filters::Mongo;

our $VERSION = '0.02';

use constant FALSE => undef;
use constant TRUE => 1;

extends 'Gideon';
has '_mongo_id' => ( is => 'rw', isa => 'MongoDB::OID' );

sub remove {

    my $self = shift;

    unless ( ref($self) ) {
        Gideon::Error->throw('remove() is not a static method');
    }

    return FALSE unless $self->is_stored;

    try {
        
        unless ( $self->_mongo_id ) {
            Gideon::Error::Simple->throw('can\'t remove() without mongo unique id');    
        }

        my $obj = $self->mongo_conn( $self->get_store_destination() );

        $obj->remove( { "_id" => $self->_mongo_id } );

        $self->is_stored(0);
        $self->is_modified(0);

        if ( Gideon->cache_registered ) {
            Gideon->cache_clear(ref $self);
        }        

        return TRUE;

    }
    catch {
        cluck ref($_) if $Gideon::EXCEPTION_DEBUG;
        croak $_;
    }

}

sub update_all {}
sub remove_all { die 'not implemented' }

sub save {

    my $self = shift;

    unless ( ref($self) ) {
        Gideon::Error->throw('save() is not a static method');
    }

    return FALSE if ( $self->is_stored and not $self->is_modified );

    try {

        my $table  = $self->get_store_destination();
        my $obj    = $self->mongo_conn($table);
        my $fields = $self->get_attributes_from_meta();

        unless ( $self->is_stored ) {

            # remove auto increment columns for insert
            $fields = $self->remove_auto_columns_for_insert($fields);
        }

        my %map = map { $_, $self->$_ } @{$fields};

        if ( $self->is_stored ) {

            if ( !$self->_mongo_id ) {
                Gideon::Error::Simple->throw('Can\'t update record without object ID');
            }
            $obj->update( { "_id" => $self->_mongo_id }, { '$set' => \%map } );

        }
        else {

            if ( my $serial = $self->get_serial_attr() ) {
                my $next_id = $self->increment_serial($table);
                $map{$serial} = $next_id;
            }

            my $id = $obj->insert( \%map );
            $self->_mongo_id($id);
            $self->is_stored(1);
            $self->is_modified(0);            
            
        }

        if ( Gideon->cache_registered ) {
            Gideon->cache_clear(ref $self);
        }        

        return $self;

    }
    catch {
        cluck ref($_) if $Gideon::EXCEPTION_DEBUG;
        croak $_;
    }

}

sub find {

    my $class = shift;
    my ( $args, $config ) = $class->decode_params(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }
    
    $args = Gideon::Filters::Mongo->format( $class->filter_rules($args) );
    
    try {

        my $cache_key;

        my $table  = $class->get_store_destination();
        my $db     = $class->mongo_conn($table);
        my $fields = $class->get_attributes_from_meta();

        if ( $class->cache_registered ) {
            $cache_key = $class->generate_cache_key( 'find', $table, $args );
            if ( my $cached_obj = $class->cache_lookup($cache_key) ) {
                my $obj = $cached_obj;
                return $obj;
            }
        }
        
        if ( my $data = $db->find( $args )->next ) {

            my $mongo_id = $data->{_id};
            my @construct_args = map { $_, $data->{$_} } keys %{$data};

            my $obj = $class->new(@construct_args);
            $obj->is_stored(1);
            $obj->_mongo_id($mongo_id);
            $obj->is_modified(0);

            if ($cache_key) {
                $class->cache_store( $cache_key, $obj );
            }

            return $obj;
        }
        
        return FALSE;

    }
    catch {
        cluck ref($_) if $Gideon::EXCEPTION_DEBUG;
        croak $_;
    };

}

sub find_all {

    my $class = shift;
    
    my ( $args, $config ) = $class->decode_params(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    $args = Gideon::Filters::Mongo->format( $class->filter_rules($args) );
    
    try {

        my $cache_key;
        my $store   = $class->get_store_destination();
        my $obj     = $class->mongo_conn( $store );
        my $results = Gideon::Mongo::Results->new(package => $class);
        my $all     = $obj->find($args);

        if ( $class->cache_registered ) {
            $cache_key = $class->generate_cache_key( 'fall', $store, $args );
            if ( my $cached_results = $class->cache_lookup($cache_key) ) {
                $results = $cached_results;
                return wantarray ? $results->records : $results;
            }
        }

        while ( my $doc = $all->next ) {

            my $mongo_id = $doc->{_id};

            my @construct_args = map { $_, $doc->{$_} } keys %{$doc};
            my $obj = $class->new(@construct_args);
            $obj->is_stored(1);
            $obj->_mongo_id($mongo_id);
            $obj->is_modified(0);

            $results->add_record($obj);
        }
        if ($cache_key) {
            $class->cache_store( $cache_key, $results );
        }
        return wantarray ? $results->records : $results;

    }
    catch {
        cluck ref($_) if $Gideon::EXCEPTION_DEBUG;
        croak $_;
    };
}

sub mongo_conn {

    my $class   = shift;
    my $table   = shift;
    my $db      = $class->get_store_id();
    my $db_conn = $class->_from_store_conn()->get_database($db);

    if ($table) {
        return $db_conn->get_collection($table);
    }

    return $db_conn;

}

sub increment_serial {

    my $self = shift;
    my $table = shift || die;

    my $serial_data = $self->mongo_conn('gideon_serial');
    my $data = $serial_data->find( { 'table' => $table } )->next;

    if ($data) {
        my $id = $data->{id} + 1;
        $serial_data->update( { "_id" => $data->{_id} }, { '$set' => { 'id' => $id } } );
        return $id;
    }

    my $id = $serial_data->insert( { 'table' => $table, 'id' => 1 } );
    return 1;

}

sub cache_store {

    my $self = shift;
    my $key  = shift;
    my $what = shift;
    
    my $class = (ref $self) ? ref $self : $self;

    return Gideon->cache_store( $key, $what, $class );

}

sub generate_cache_key {

    my $self = shift;
    my $from = shift;
    my $tabl = shift;
    my $flds = shift;
    
    my $vals = join( '_', map { $flds->{$_} } keys %$flds );
    my $key = $self->signature_for_cache . $from . $tabl . $vals;    # uniqueness generated with sql query and filters

    my $module = $self->get_cache_module;
    return $module->digest($key);

}

sub like {
    my $class = shift;
    my $string = shift || "";
    return qr/$string/i;
}

sub lt {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub gt {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub gte {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub lte {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub ne {
    my $class = shift;
    my $string = shift || "";
    return $string;
}

sub remove_auto_columns_for_insert {

    my $self  = shift;
    my $field = shift;

    my $serial = $self->get_serial_columns_hash;
    my $filter = [];

    foreach ( @{$field} ) {
        unless ( exists $serial->{$_} ) {
            push @{$filter}, $_;
        }
    }
    $field = $filter;
    return $field;

}

# Private ----------------------------------------------------------------------

sub _from_store_conn {

    my $class = shift;
    my $store = $class->get_store_args();

    if ( ref($store) eq 'MongoDB::Connection' ) {
        return $store;
    }

    if ( ref($store) and $store->can('connect') ) {
        return $store->connect();
    }

    return $store;

}

__PACKAGE__->meta->make_immutable();
