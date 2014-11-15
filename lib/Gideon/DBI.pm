package Gideon::DBI;

use Moose;
use warnings;
use Gideon::Error;
use Gideon::Error::Simple;
use Gideon::Filters::DBI;
use Gideon::Error::DBI;
use Gideon::Error::Params;
use Gideon::Error::DBI::NotFound;
use Gideon::DBI::Results;
use Gideon::DBI::Common;
use Try::Tiny;
use DBI 1.60;
use Carp qw(cluck carp croak);
use Data::Dumper qw(Dumper);
use Gideon::Meta::Attribute::DBI;

our $VERSION = '0.02';
our $DBI_DEBUG = 0;

use constant FALSE => undef;
use constant TRUE => 1;

extends 'Gideon';

has 'conn' => ( is => 'rw', isa => 'Maybe[Str]' );

sub remove {

    my $self = shift;

    unless ( ref($self) ) {
        return $self->remove_all(@_);
    }

    return FALSE unless $self->is_stored;

    try {

        my $fields = $self->metadata->get_key_columns_hash();

        if ( scalar( keys %{$fields} ) == 0 ) {
            Gideon::Error->throw('can\'t delete without table primary key');
        }

        my %where = map { $fields->{$_} => $self->$_ } sort keys %{$fields};
        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'delete', $self->storage->origin(), \%where );

        my $pool = $self->conn;
        my $dbh = $self->dbh($pool,1);
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( msg => $sth->errstr, stmt => $stmt, params => \@bind );

        $sth->finish;
        $self->is_stored(0);
        $self->is_modified(0);

        if ( Gideon->cache->is_registered ) {
            Gideon->cache->clear(ref $self);
        }

        return TRUE;

    }
    catch {
        my $e = shift;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak $e;
    }

}

sub update {

    my $class = shift;

    if ( ref($class) ) {
        Gideon::Error->throw('update() is a static method');
    }

    my ( $args, $config ) = $class->params->decode(@_);

    try {

        my $map   = $class->metadata->map_args_with_column($args);
        my $where = $class->where_stmt_from_args($args);
        my $limit = $config->{limit} || '';
        my $pool  = $config->{conn} || '';

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'update', $class->storage->origin(), $where, undef, undef, $limit );

        my $dbh = $class->dbh($pool,1);
        my $sth = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( msg => $sth->errstr, stmt => $stmt, params => \@bind );
        $sth->finish;

        if ( Gideon->cache->is_registered ) {
            Gideon->cache->clear($class);
        }

        return $rows;

    }
    catch {
        croak shift;
    }
}

sub update_all {

    my $class = shift;
    my ( $args, $config ) = $class->params->decode(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('update_all() is a static method');
    }
    if (not %$args) {
        Gideon::Error->throw('update_all() called without arguments');
    }

    try {

        my $map   = $class->metadata->map_args_with_column($args);
        my $where = $class->where_stmt_from_args($args);
        my $limit = $config->{limit} || '';
        my $pool  = $config->{conn} || '';

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'update', $class->storage->origin(), $where, undef, undef, $limit );

        my $dbh = $class->dbh($pool,1);
        my $sth = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $sth->errstr );
        $sth->finish;

        if ( Gideon->cache->is_registered ) {
            Gideon->cache->clear($class);
        }

        return $rows;

    }
    catch {
        croak shift;
    }
    
}

sub remove_all {

    my $class = shift;
    my ( $args, $config ) = $class->params->decode(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('remove_all() is a static method');
    }

    $args = $class->params->normalize($args);

    try {

        my $map   = $class->metadata->map_args_with_column($args);
        my $where = $class->where_stmt_from_args($args);
        my $limit = $config->{limit} || '';
        my $pool  = $config->{conn} || '';

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'delete', $class->storage->origin(), $where, undef, undef, $limit );

        my $dbh = $class->dbh($pool,1);
        my $sth = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $sth->errstr );
        $sth->finish;

        if ( Gideon->cache->is_registered ) {
            Gideon->cache->clear($class);
        }

        return $rows;

    }
    catch {
        croak shift;
    }
}

sub save {

    my $self = shift;

    unless ( ref($self) ) {
        Gideon::Error->throw('save() is not a static method');
    }

    return FALSE if ( $self->is_stored and not $self->is_modified );

    try {

        my $where  = {};
        my $fields = $self->metadata->get_columns_hash();

        if ( $self->is_stored ) {
            $where = $self->get_key_columns_for_update();
        }
        else {

            # remove auto increment columns for insert
            $self->remove_auto_columns_for_insert($fields);
        }

        my %data = $self->stringify_fields($fields);
        my $stmt = '';
        my @bind = ();

        if ( $self->is_stored ) {
            ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'update', $self->storage->origin(), \%data, $where );
        }
        else {
            ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'insert', $self->storage->origin(), \%data );
        }

        my $pool = $self->conn;
        my $dbh = $self->dbh($pool,1);
        my $sth  = $dbh->prepare($stmt) or Gideon::Error::DBI->throw( $dbh->errstr );
        my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( msg => $sth->errstr, stmt => $stmt, params => \@bind );
        $sth->finish;

        if ( !$self->is_stored and my $serial = $self->metadata->get_serial_columns_hash ) {
            my $last_id = $self->last_inserted_id($dbh);
            my $serial_attribute = ( map { $_ } keys %{$serial} )[0];
            $self->$serial_attribute($last_id);
        }

        $self->is_stored(1);
        $self->is_modified(0);

        if ( Gideon->cache->is_registered ) {
            Gideon->cache->clear(ref $self);
        }

        return $self;

    }
    catch {
        my $e = shift;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak $e;
    }

}

sub last_inserted_id {

    my $self = shift;
    my $dbh = shift || die;
    my $query = "select last_insert_id() as last";

    if ( $self->_is_sqlite ) {
        my $t = $self->storage->origin();
        $query = "SELECT ROWID as last from $t order by ROWID DESC limit 1";
    }

    my $sth  = $dbh->prepare($query) or die $dbh->errstr;
    my $rows = $sth->execute or die $sth->errstr;
    my %row = ();

    $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) );
    $sth->fetch;
    $sth->finish;

    return $row{'last'};

}

sub find {

    my $class = shift;
    my ( $args, $config ) = $class->params->decode(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    $args = $class->params->normalize($args);

    try {

        my $cache_key;

        my $fields = $class->get_columns_escaped_with_table();
        my $map    = $class->metadata->map_args_with_column($args);
        my $where  = $class->where_stmt_from_args($args);
        my $order  = $config->{order_by} || [];
        my $limit  = $config->{limit} || '';
        my $pool   = $config->{conn} || '';

        my ( $stmt, @bind ) =
          Gideon::Filters::DBI->format( 'select', $class->storage->origin(), $fields, $where, $class->add_table_to_order($order), $limit );

        my $obj;

        if ( $class->cache->is_registered ) {
            $cache_key = $class->generate_cache_key( 'find', $stmt, @bind );
            if ( my $cached_obj = $class->cache->lookup($cache_key) ) {
                $obj = $cached_obj;
                return $obj;
            }
        }

        my $rows = Gideon::DBI::Common->execute_one_with_bind_columns(
            'dbh'   => $class->dbh($pool,1),
            'query' => $stmt,
            'bind'  => [@bind],
            'block' => sub {

                my $row = shift;
                my @construct_args = $class->args_for_new_object($row);
                $obj = $class->new(@construct_args);
                $obj->is_stored(1);
                $obj->is_modified(0);
                $obj->conn($pool) if $pool;

            }
        );

        Gideon::Error::DBI::NotFound->throw('no results found ' . $class) unless $obj;

        if ($cache_key) {
            $class->cache->store( $cache_key, $obj );
        }

        return $obj;

    }
    catch {
        my $e = shift;
        Gideon::DBI::Common->finish;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak $e;
    }

}

sub find_all {

    my $class = shift;
    my ( $args, $config ) = $class->params->decode(@_);

    if ( ref($class) ) {
        Gideon::Error->throw('find() is a static method');
    }

    $args = $class->params->normalize($args);

    try {

        my $cache_key;

        my $fields = $class->get_columns_escaped_with_table();
        my $map    = $class->metadata->map_args_with_column($args);
        my $where  = $class->where_stmt_from_args($args);
        my $order  = $config->{order_by} || [];
        my $limit  = $config->{limit} || '';
        my $pool   = $config->{conn} || '';

        my $destination = $class->storage->origin();

        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'select', $destination, $fields, $where, $class->add_table_to_order($order), $limit );

        my $results = Gideon::DBI::Results->new(
            package => $class,
            where   => $where,
            conn    => $pool,
        );

        if ( $class->cache->is_registered ) {
            $cache_key = $class->generate_cache_key( 'fall', $stmt, @bind );
            if ( my $cached_results = $class->cache->lookup($cache_key) ) {
                $results = $cached_results;
                return wantarray ? $results->records : $results;
            }
        }

        my $rows = Gideon::DBI::Common->execute_with_bind_columns(
            'dbh'   => $class->dbh($pool,1),
            'query' => $stmt,
            'bind'  => [@bind],
            'block' => sub {

                my $row = shift;
                my @construct_args = $class->args_for_new_object($row);
                my $obj            = $class->new(@construct_args);

                $obj->is_stored(1);
                $obj->is_modified(0);

                $results->add_record($obj);

            }
        );

        if ($cache_key) {
            $class->cache->store( $cache_key, $results );
        }

        return wantarray ? $results->records : $results;

    }
    catch {
        my $e = shift;
        Gideon::DBI::Common->finish;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak $e;
    }
}

sub generate_cache_key {

    my $self = shift;
    my $from = shift;
    my $stmt = shift;
    my @args = @_;

    my $vals = join '_', @args;
    my $key = $self->cache->signature . $from . $stmt . $vals;    # uniqueness generated with sql query and filters

    my $module = $self->cache->get_module;
    return $module->digest($key);

}

sub add_table_to_order {

    my $class = shift;
    my $table = $class->storage->origin();
    my $sort  = shift;

    if ( ref($sort) eq 'ARRAY' ) {
        foreach my $clauses ( @{$sort} ) {
            if ( ref($clauses) eq 'HASH' ) {
                $class->_loop_sort_conditions( $clauses, $table );
            }
            elsif ( ref($clauses) eq 'ARRAY' ) {
                my $converted = [];
                foreach my $dirs ( @{$clauses} ) {
                    push @{$converted}, $class->_loop_sort_conditions( $dirs, $table );
                }
                $clauses = $converted;
            }
            else {
                $clauses = $table . '.' . $clauses;
            }
        }
    }
    unless ( ref($sort) ) {
        $sort = $table . '.' . $sort;
    }

    return $sort;
}

sub where_stmt_from_args {
    my $class = shift;
    my $args  = shift;

    my $map   = $class->metadata->map_args_with_column($args);
    my $table = $class->storage->origin();

    my %where = ();
    my @where = ();

    foreach my $attr (sort keys %$map) {
        if ($attr eq '-or' and ref $map->{$attr} eq 'HASH') {
            my $sub_map = $map->{$attr};
            foreach my $sub_attr (sort keys %$sub_map) {
                my $or = {};
                $or->{$table.'.'.$sub_attr} = $args->{ $attr }->{ $map->{$attr}->{$sub_attr} };
                push @where, $or;
            }
        }
        else {
            $where{$table.'.'.$attr} = $args->{ $map->{$attr} }
        }
    }

    if (scalar @where) {
        if (scalar keys %where) {
            # for conditions + regular where: ( -or => { key => value, .... }, key => value .... )
            return [ -and => [ \%where, [ -or => \@where ] ] ]
        }
        # for conditions where: ( -or => { key => value, .... }  )
        return \@where
    }
    # regular where: { key => value, ..... }
    return \%where;
}

sub get_column_with_table {

    my $class     = shift;
    my $attribute = shift;

    my $table  = $class->storage->origin();
    my $column = $class->metadata->get_column_for_attribute($attribute) || warn "failed $class $attribute";

    return $table . '.' . $column;
}

sub add_table_to_where {

    my $class = shift;
    my $table = $class->storage->origin();
    my %where = @_;

    return map { $table . '.' . $_ => $where{$_} } sort keys %where;
}

sub get_columns_escaped_with_table {

    my $class = shift;
    my $table = $class->storage->origin();

    my @columns = $class->metadata->get_columns_from_meta();
    my @escaped = map { $table . '.' . $_ . ' as `' . $table . '.' . $_ . '`' } sort @columns;

    return wantarray ? @escaped : \@escaped;
}

sub columns_with_table_as_list {

    my $class = shift;
    my $table = $class->storage->origin();

    my $columns = $class->metadata->get_columns_from_meta();
    my @columns = map { $table . '.' . $_ } @{$columns};

    return wantarray ? @columns : \@columns;
}

sub map_meta_with_row {

    my $class = shift;
    my $row   = shift;
    my $map   = {};

    foreach my $r ( keys %{$row} ) {
        my ( $table, $col ) = split( /\./, $r );
        my $attribute = $class->metadata->get_attribute_for_column($col);
        next unless $attribute;
        $map->{$attribute} = $r;
    }

    return $map;

}

sub dbh {

    my $self = shift;
    my $pool = shift;
    my $exclusive = shift || 0;

    return $self->_from_store_dbh($pool,$exclusive);

}

sub begin_work {
    my $self = shift;
    $self->dbh->{AutoCommit} = 0;
    if ( $self->_is_sqlite ) {
        return;
    }
    $self->dbh->begin_work;
}

sub commit {
    my $self = shift;
    $self->dbh->commit;
    $self->dbh->{AutoCommit} = 1;
}

sub rollback {
    my $self = shift;
    $self->dbh->rollback;
    $self->dbh->{AutoCommit} = 1;
}

sub eq {
    my $class  = shift;
    my $string = shift;
    return $string;
}

sub lt {
    my $class  = shift;
    my $string = shift;
    return $string;
}

sub gt {
    my $class  = shift;
    my $string = shift;
    return $string;
}

sub gte {
    my $class  = shift;
    my $string = shift;
    return $string;
}

sub lte {
    my $class  = shift;
    my $string = shift;
    return $string;
}

sub ne {
    my $class  = shift;
    my $string = shift;
    return $string;
}

sub stores_for_foreign {

    my $self = shift;
    my $other = shift;
    my @stores = ();

    push @stores, $self->storage->origin;
    push @stores, $other->storage->origin;

    return wantarray ? @stores : join ',', @stores;

}

sub columns_meta_for_foreign {

    my $self = shift;
    my $other = shift;
    my @fields = ();

    my @myfields = $self->get_columns_escaped_with_table;
    my @foreign = $other->get_columns_escaped_with_table;

    push @fields, ( @myfields, @foreign );

    return wantarray ? @fields : join ',', @fields;

}

sub execute_and_array {

    my $class  = shift;
    my $tables = shift;
    my $fields = shift;
    my $where  = shift;
    my $order  = shift;
    my $group  = shift;

    my $sql = SQL::Abstract->new;
    my $cache_key;

    my ( $stmt, @bind ) = $sql->select( $tables, $fields, $where, $order );

    if ($group) {
        $stmt = $class->_add_group_by( $stmt, $group );
    }

    if ( $class->cache->is_registered ) {
        $cache_key = $class->generate_cache_key( 'earr', $stmt, @bind );
        $class->cache->lookup($cache_key);
    }

    my $sth  = $class->dbh()->prepare_cached($stmt) or Gideon::Error::DBI->throw( $class->dbh->errstr );
    my $rows = $sth->execute(@bind) or Gideon::Error::DBI->throw( $sth->errstr );
    my %row;

    $sth->bind_columns( \( @row{ @{ $sth->{NAME_lc} } } ) );

    my $results = Gideon::DBI::Results->new(
        package => $class,
        where   => $where,
    );

    while ( $sth->fetch ) {
        my %rec = map { $_, $row{$_} } keys %row;
        $results->add_record( \%rec );
    }

    $sth->finish;

    if ($cache_key) {
        $class->cache->store( $cache_key, $results );
    }

    return $results;
}

sub order_from_config {
    my $self   = shift;
    my $config = shift;
    my $order;
    if ( exists $config->{ordered} and my $order_clause = $config->{ordered} ) {
        $order = [$order_clause];
    }
    return $order;
}

sub function {

    my $class = shift;
    my $function = shift;
    my $attr = shift;

    if ( ref($class) ) {
        Gideon::Error->throw($function . 'max is a static method');
    }
    if ( !$attr ) {
        Gideon::Error->throw('missing attribute');
    }
    if ( ref($attr) ) {
        Gideon::Error->throw('first argument is not valid');
    }

    my $column = $class->metadata->get_column_for_attribute($attr);

    if (not $column and $attr ne '*') {
        Gideon::Error->throw('invalid attribute ' . $attr);
    }
    if (not $column and $attr eq '*') {
        $column = $attr
    }

    my ( $args, $config ) = $class->params->decode(@_);
    $args = $class->params->normalize($args);

    try {

        my $where = $class->where_stmt_from_args($args);
        my $pool  = $config->{conn} || '';
        my $fields = $class->_function_to_query($function,$column);
        my ( $stmt, @bind ) = Gideon::Filters::DBI->format( 'select', $class->storage->origin(), $fields, $where, undef, undef);

        my $num = 0;
        my $rows = Gideon::DBI::Common->execute_one_with_bind_columns(
            'dbh'   => $class->dbh($pool,1),
            'debug' => $DBI_DEBUG,
            'query' => $stmt,
            'bind'  => [@bind],
            'block' => sub {
                my $row = shift;
                $num = $row->{$function} || 0;
            }
        );
        return $num;

    }
    catch {
        my $e = shift;
        cluck ref($e) if $Gideon::EXCEPTION_DEBUG;
        croak "Error calling function ($function) for attribute '$attr', " . $e;
    }

}

# Private ----------------------------------------------------------------------

sub _from_store_dbh {

    my $self = shift;
    my $pool = shift;
    my $excl = shift;

    my $dbh;
    my $store = $self->storage->args($pool);

    if ( ref($store) eq 'DBI::db' ) {
        $dbh = $store;
        return $dbh;
    }

    if ( ref($store) and $store->can('connect') ) {
        my $dbh = $store->connect($excl);
        return $dbh;
    }

    my $dbi_string = $store;
    my $user       = '';
    my $pw         = '';

    unless ( $dbh = DBI->connect( $dbi_string, $user, $pw, { RaiseError => 0, PrintError => 0 } ) ) {
        Gideon::Error::Simple->throw($DBI::errstr);
    }

    return $dbh;
}

sub remove_auto_columns_for_insert {

    my $self  = shift;
    my $field = shift;

    my $serial = $self->metadata->get_serial_columns_hash;

    foreach ( keys %{$serial} ) {
        delete $field->{$_};
    }

}

sub get_key_columns_for_update {

    my $self  = shift;
    my $where = {};

    my $keys = $self->metadata->get_key_columns_hash;

    if ( scalar( keys %{$keys} ) == 0 ) {
        Gideon::Error->throw('can\'t update without table primary key');
    }

    foreach ( keys %{$keys} ) {
        $where->{ $keys->{$_} } = $self->$_;
    }

    return $where;

}

sub args_for_new_object {

    my $class = shift;
    my $row   = shift;

    my $map = $class->map_meta_with_row($row);
    return map { $_ => $row->{ $map->{$_} } } ( keys %{$map} );

}

sub args_with_db_values {

    my $class          = shift;
    my $construct_args = shift;
    my $row            = shift;

    return map { $_ => $row->{ $construct_args->{$_} } } ( keys %{$construct_args} );

}

sub _loop_sort_conditions {

    my $class   = shift;
    my $clauses = shift;
    my $table   = shift;

    foreach my $dirs ( keys %{$clauses} ) {
        if ( ref( $clauses->{$dirs} ) eq 'ARRAY' ) {
            foreach ( @{ $clauses->{$dirs} } ) {
                $_ = $table . '.' . $_;
            }
        }
        else {
            $clauses->{$dirs} = $table . '.' . $clauses->{$dirs};
        }
    }

    return $clauses;

}

sub _add_group_by {

    my $self  = shift;
    my $stmt  = shift;
    my $group = shift;

    my @valid_params = $self->columns_with_table_as_list;

    unless ( grep { /^$group/ } @valid_params ) {
        Gideon::Error::Params->throw( 'not valid object meta data \`' . $group );
    }

    my $group_clause = ' group by `' . $group . '`';

    if ( $stmt =~ /ORDER BY/ ) {
        $stmt =~ s/ORDER BY/$group_clause ORDER BY/;
    }
    else {
        $stmt .= $group_clause;
    }

    return $stmt;
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

sub _function_to_query {

    my $class = shift;
    my $function = shift;
    my $column = shift;

    my $map = {
        'MIN' => 'min(%s) as %s',
        'MAX' => 'max(%s) as %s',
        'SUM' => 'sum(%s) as %s',
        'COUNT' => 'count(%s) as %s',
        'COUNT_DISTINCT' => 'count(distinct(%s)) as %s',
    };

    Gideon::Error->throw("invalid function called ($function)") unless exists $map->{uc($function)};

    if ($column ne '*') {
        $column = "`$column`";
    }

    return sprintf $map->{uc($function)}, $column, $function

}

sub _is_sqlite {
    my $self = shift;
    my $pool = $self->conn;
    my $dbh_info = $self->dbh($pool)->get_info(17);
    if ( $dbh_info and index( $dbh_info, 'SQLite' ) >= 0 ) {
        return 1;
    }
    return 0;
}

__PACKAGE__->meta->make_immutable();
