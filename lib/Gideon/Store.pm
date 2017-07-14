package Gideon::Store;

use Moose;
use Gideon::Error;
use Data::Dumper qw(Dumper);
use MooseX::ClassAttribute;

has 'stores' => ( is => 'rw', isa => 'HashRef', lazy => 1, default => sub {{}} );
has '_last_used' => ( is => 'rw', isa => 'HashRef', lazy => 1, default => sub {{}} );
has '_packages' => ( is => 'rw', traits => ['Array'], isa => 'ArrayRef[HashRef]',
    handles => {
        find_package => 'first',
        add_package => 'push',
        packages => 'elements',
        package => 'get',
    }
);
class_has 'who' => ( is => 'rw', isa => 'Str' );

sub register {

    my $self = shift;
    my $params = {
        name => undef,
        args => undef,
        strict => 0,
    ,@_};

    my $name = $params->{name};
    my $args = $params->{args};
    my $strict = $params->{strict};

    if (not $name) {
        Gideon::Error->throw('provide a name for your store');
    }
    if (not $args) {
        Gideon::Error->throw('provide connection information for your store');
    }

    unless ( $self->is_store_registered($name) ) {

        $self->stores->{ $name }->{args} = $args;
        $self->stores->{ $name }->{strict} = $strict;

    }

    return 1;

}

sub args {

    my $self = shift;
    my $node = shift;
    my $id   = $self->id;

    $self->check_store;

    my $pkg = $self->who;
    my $args = $self->by_name_get_args( $id );

    if ( ref($args) eq 'Gideon::Connection::Pool' ) {
        if ($node) {
            # return node and select it
            return $self->select($node)
        }
        else {
            return $self->last_used
        }
    }
    if ($node) {
        Gideon::Error->throw("can't use $node, either pool is not defined or node is invalid")
    }

    return $args;

}

sub by_name_get_args {
    my $self = shift;
    my $name = shift;
    die "invalid name '$name' given" if not exists $self->stores->{ $name };
    my $args = $self->stores->{ $name }->{args};
    return $args;
}

sub select {

    my $self = shift;
    my $node = shift;

    if ( $self->who eq __PACKAGE__ or $self->who eq 'Gideon' ) {
        Gideon::Error->throw('use select() from your own class');
    }

    my $id   = $self->id;
    my $pool = $self->by_name_get_args( $id );
    my $pkg  = $self->who;

    unless ( ref($pool) eq 'Gideon::Connection::Pool' ) {
        Gideon::Error->throw("not a valid pool class defined in class $pkg");
    }

    # switch to requested node if exists
    return $self->from_pool($pool,$node);

}

sub last_used {

    my $self = shift;
    my $pkg  = $self->who;

    if ( not exists $self->_last_used->{ $pkg } ) {
        Gideon::Error->throw("your store is a connection pool but no selection was made and node wasn't specified");
    }

    if (my $last = $self->_last_used->{ $pkg } ) {
        return $last;

    }

    Gideon::Error->throw("use select() to switch to a valid node from your pool");
}

sub from_pool {

    my $self = shift;
    my $pool = shift;
    my $node = shift;
    my $pkg  = $self->who;

    if ( $self->who eq __PACKAGE__ or $self->who eq 'Gideon' ) {
        Gideon::Error->throw('use from_pool() from your own class');
    }

    if ( ref($pool) eq 'Gideon::Connection::Pool' ) {
        if ($node) {
            unless ($pool->detect($node)) {
                Gideon::Error->throw('invalid identifier ' .$node . ' is not in the pool');
            }
            $self->_last_used->{ $pkg } = $pool->get($node);
            return $pool->get($node)
        }
        else {
            $self->last_used;
        }
    }

}

sub transaction {

    my $self = shift;
    my $store = shift || $self->id;
    my $pkg = $self->who;
    # TODO: support pools
    if (my $args = $self->by_name_get_args( $store )) {
        return $args
    }

    Gideon::Error->throw("$store is not registered or name is invalid $pkg")
}

sub origin {

    my $self = shift;

    die 'cannot identify who is calling me' if not $self->who;
    my $found = $self->find_package( sub { $_->{name} eq $self->who } );
    die 'invalid class' if not $found;

    if (exists $found->{origin}) {
        return $found->{origin}
    }

    my ($store,$origin) = split ':', $found->{store}, 2;
    $found->{origin} = $origin;
    return $origin;
}

sub check_store {

    my $self = shift;
    my $id = $self->id;
    my $origin = $self->origin;
    die 'invalid store \'' .$id . '\' from class '. $self->who .', use Gideon->register(\'' . $id . '\', ... )' unless exists $self->stores->{ $id };
    return 1;
}

sub id {

    my $self = shift;

    die 'cannot identify who is calling me' if not $self->who;
    my $found = $self->find_package( sub { $_->{name} eq $self->who } );
    die 'invalid class' if not $found;

    if (exists $found->{id}) {
        return $found->{id}
    }

    my ($store,$origin) = split ':', $found->{store}, 2;
    $found->{id} = $store;
    return $store;

}

sub is_store_registered {

    my $self = shift;
    my $name = shift || die 'invalid name';

    if ( exists $self->stores->{ $name } ) {
        die 'store \''. $name .'\' is already registered'
            if $self->stores->{ $name }->{strict} == 1;
    }

    return;

}

sub _get_pkg_name {
    my $self = shift;
    return ref($self) ? ref($self) : $self
}

__PACKAGE__->meta->make_immutable();
no Moose;
1;

