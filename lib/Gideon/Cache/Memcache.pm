package Gideon::Cache::Memcache;

use strict;
use warnings;
use autodie;
use Digest::SHA2;
use 5.012_001;
use Data::Dumper qw(Dumper);
use Cache::Memcached;
use Time::HiRes qw(usleep gettimeofday tv_interval);

use constant MEMCACHE_DEBUG => 0;
use constant MEMCACHE_LOCK_DEBUG => 0;
use constant COMPRESS_TRESH => 10_000;
use constant LOCK_TIMEOUT => 10; # secs
use constant LOCK_RETRY_WAIT => 100; #milisecs

our $slot    = '_DEFAULT_';
our $servers = ["127.0.0.1:11211"];

our $_class_ttl = {};

my $memd;
my $class_stats = {};
my $hits = 0;

sub get {

    my $self = shift;
    my $key  = shift;

    my $slot_plus_key = $slot.$key;

    if ( my $cached = $memd->get($slot_plus_key) ) {
        if(ref($cached) eq 'Gideon::DBI::Results') {
            # check if result set is still valid
            if (my $belongs = ref($cached->first)) {
                my $t0 = [gettimeofday];
                my $found = 0;
                # esto se puede poner lento si son muchas keys por cada clase
                foreach ($self->class_keys($belongs)) {
                    if ($_ eq $key) {
                        $found = 1;
                        last
                    }
                }
                my $elapsed = tv_interval( $t0 );
                unless ( $found ) {
                    warn __PACKAGE__ . " $key is not valid took $elapsed secs";
                    $self->delete($slot_plus_key);
                    return;
                }
                if ($elapsed > 0.400) {
                    warn __PACKAGE__ . " check took $elapsed $belongs"
                }
            }
        }
        $self->increment_hits;
        return $cached;
    }
    return;
}

sub increment_hits {
    my $self = shift;
    return unless $memd;
    if ($memd->incr('__gdn_priv_hits')) {
    } else {
        $memd->set('__gdn_priv_hits',1);
    }
}

sub set {

    my $self     = shift;
    my $key      = shift;
    my $contents = shift;
    my $ttl      = shift;
    my $class    = shift || '__invalid__';

    if (my $pid = $self->_get_class_lock($class)) {
        warn "set $pid is locking $class ..." if MEMCACHE_LOCK_DEBUG;
        usleep LOCK_RETRY_WAIT;
        return $self->set($key,$contents,$ttl,$class);
    }

    # avoid race condition when multiple set() is called
    $self->_set_class_lock($class);

    # save key for this class
    $self->_add_key_to_class($key,$class);

    # done deleting keys for this class
    $self->_delete_class_lock($class);

    if (exists $_class_ttl->{$class} and $_class_ttl->{$class} > 0) {
        $ttl = $_class_ttl->{$class}
    }

    # keep simple stats for testing
    $class_stats->{$slot}->{$class}++;

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

    if (my $pid = $self->_get_class_lock($class)) {
        warn "clear $pid is locking ... $class" if MEMCACHE_LOCK_DEBUG;
        usleep LOCK_RETRY_WAIT;
        return $self->clear($class);
    }

    # avoid race condition when multiple clear() is called
    $self->_set_class_lock($class);

    my @keys = $self->class_keys($class);
    $self->_delete_class_cache($class);

    # done deleting keys for this class
    $self->_delete_class_lock($class);

    foreach my $k (@keys) {
        my $found = $self->delete($k);
        if (!$found) {
            warn "$class $k not found" if MEMCACHE_LOCK_DEBUG
        }
    }

    return;

}

sub digest {
    my $self = shift;
    my $string = shift;
    my $sha1 = Digest::SHA2->new;
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
    return $servers;
}

sub memd {
    return $memd;
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

    foreach my $class (keys %{$class_stats->{$slot}}) {
        if (my $class_keys = $self->_get_class_cache($class)) {
            push @list, keys %{$class_keys};
        }
    }
    #warn Dumper($class_stats);
    return scalar @list;

}

sub slot_count {
    return scalar keys %$class_stats
}

sub content {
    # not implemented
    return {}
}

sub hits {
    my $self = shift;
    return unless $memd;
    return $memd->get('__gdn_priv_hits')||0;
    #return $hits;
}

sub class_keys {

    my $self = shift;
    my $class = shift || die;
    my @list = ();

    if (my $class_keys = $self->_get_class_cache($class)) {
        if (ref $class_keys eq 'HASH') {
            @list = keys %{$class_keys};
        }
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
    return Cache::Memcached->new({
        'servers' => $servers,
        'debug'   => MEMCACHE_DEBUG,
    })
}

sub _get_class_lock {
    my $self = shift;
    my $class = shift || die;
    my $namespace = $self->_class_namespace($class);
    return unless $memd;
    warn $namespace if MEMCACHE_LOCK_DEBUG;
    return $memd->get("__gdn_priv_lock_$namespace");
}

sub _set_class_lock {
    my $self = shift;
    my $class = shift || die;
    my $namespace = $self->_class_namespace($class);
    return $memd->set("__gdn_priv_lock_$namespace",$$,LOCK_TIMEOUT);
}

sub _delete_class_lock {
    my $self = shift;
    my $class = shift || die;
    my $namespace = $self->_class_namespace($class);
    return $memd->delete("__gdn_priv_lock_$namespace");
}

sub _get_class_cache {
    my $self = shift;
    my $class = shift || die;
    my $namespace = $self->_class_namespace($class);
    return unless $memd;
    my $keys_in_class = $memd->get("__gdn_priv_class_cache_$namespace");
    #warn Dumper($keys_in_class);# if MEMCACHE_DEBUG;
    return $keys_in_class;
}

sub _add_key_to_class {
    my $self = shift;
    my $key = shift || '';
    my $class = shift || die;
    my $class_keys = $self->_get_class_cache($class);
    $class_keys->{$key} = 1;
    return $self->_update_class_cache($class,$class_keys);
}

sub _delete_class_cache {
    my $self = shift;
    my $class = shift || die;
    my $namespace = $self->_class_namespace($class);
    warn "Delete $namespace from cache" if MEMCACHE_DEBUG;
    return $memd->delete("__gdn_priv_class_cache_$namespace");
}

sub _update_class_cache {
    die if scalar @_ < 3;
    my $self = shift;
    my $class = shift || die;
    my $hash = shift || {};
    my $namespace = $self->_class_namespace($class);
    return $memd->set("__gdn_priv_class_cache_$namespace",$hash);
}

sub _class_namespace {
    my $self = shift;
    my $class = shift || die;
    return $slot.$class;
}

1;
