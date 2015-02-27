package Gideon::Cache::Memcache;

use strict;
use warnings;
use autodie;
use Digest::SHA1;
use 5.012_001;
use Data::Dumper qw(Dumper);
use Cache::Memcached;

use constant MEMCACHE_DEBUG => 0;
use constant COMPRESS_TRESH => 10_000;

our $slot    = '_DEFAULT_';
our $servers = ["127.0.0.1:11211"];

our $_class_ttl = {};

my $memd;
my $hits = 0;

sub get {

    my $self = shift;
    my $key  = shift;

    my $slot_plus_key = $slot.$key;

    if ( my $cached = $memd->get($slot_plus_key) ) {
        $hits++;
        return $cached;
    }
    return;
}

sub set {

    my $self     = shift;
    my $key      = shift;
    my $contents = shift;
    my $ttl      = shift;
    my $class    = shift || '';

    my $namespace = $self->get_slot.$class;
    my $class_keys = $self->_get_class_cache;
    $class_keys->{$namespace}->{$key} = 1;
    $self->_update_class_cache($class_keys);

    if (exists $_class_ttl->{$class} and $_class_ttl->{$class} > 0) {
        $ttl = $_class_ttl->{$class}
    }

    my $slot_plus_key = $slot.$key;
    return $memd->set($slot_plus_key, $contents, $ttl);

}

sub delete {
    my $self = shift;
    my $key = shift;
    my $slot_plus_key = $slot.$key;
    return $memd->delete($slot_plus_key);
}

sub clear {

    my $self = shift;
    my $class = shift || die;

    my @keys = $self->class_keys($class);

    $self->_delete_class_cache($class);

    foreach my $k (@keys) {
        my $found = $self->delete($k);
        if (!$found) {
            warn "$class $k not found in cache" if MEMCACHE_DEBUG
        }
    }

}

sub digest {
    my $self = shift;
    my $string = shift;
    my $sha1 = Digest::SHA1->new;
    $sha1->add($string);
    my $hash = $sha1->hexdigest;
    return $hash;
}

sub start {
    my $self = shift;
    my $ref = shift;

    if (ref $ref eq 'ARRAY') {
        # reconnect with new servers
        $memd = $self->_connect;
    }
    else {
        # if connected return
        if ( not defined $memd ) {
            $memd = $self->_connect
        }
    }
    return $memd;
}

sub get_servers {
    my $self = shift;
    return $servers;
}

sub set_servers {
    my $self = shift;
    my $ref = shift || [];
    if (ref $ref eq 'ARRAY') {
        $servers = $ref;
        $self->start($ref);
    }
    return $self;
}

sub count {
    my $self = shift;
    # return $memd->stats('misc')->{total}->{curr_items};
    my @list = ();
    my $class_keys = $self->_get_class_cache;

    foreach my $class (keys %$class_keys) {
        push @list, keys $class_keys->{$class};
    }
    return scalar @list;

}

sub content {
    # not implemented
    return {}
}

sub hits {
    my $self = shift;
    return $hits;
}

sub class_keys {

    my $self = shift;
    my $class = shift;

    my @list = ();
    my $namespace = $self->get_slot.$class;
    my $class_keys = $self->_get_class_cache;

    if (exists $class_keys->{$namespace}) {
        @list = keys $class_keys->{$namespace};
    }
    return @list;
}

sub add_class_ttl {
    my $self = shift;
    my $class = shift || die 'no class specified';
    my $ttl = shift || 1;
    $_class_ttl->{$class} = $ttl;
    return $self;
}

sub default_slot {
    my $self = shift;
    $slot = '_DEFAULT_';
    return $self
}

sub set_slot {
    my $self = shift;
    $slot = shift;
    return $self
}

sub get_slot {
    return $slot
}

# private ----------------------------------------------------------------------

sub _connect {
    my $self = shift;
    return new Cache::Memcached {
        'servers'            => $servers,
        'debug'              => MEMCACHE_DEBUG,
        'compress_threshold' => COMPRESS_TRESH,
    };
}

sub _get_class_cache {
    my $self = shift;
    my $classes = $memd->get('__gdn_priv_class_cache');
    #warn Dumper($classes) if MEMCACHE_DEBUG;
    return $classes;
}

sub _delete_class_cache {
    my $self = shift;
    my $class = shift || die;
    my $namespace = $self->get_slot.$class;
    warn "Delete $namespace from cache" if MEMCACHE_DEBUG;
    my $classes = $self->_get_class_cache;
    delete $classes->{$namespace};
    return $self->_update_class_cache($classes);
}

sub _update_class_cache {
    my $self = shift;
    my $hash = shift || {};
    return $memd->set('__gdn_priv_class_cache',$hash);
}

1;
