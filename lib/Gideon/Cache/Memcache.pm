package Gideon::Cache::Memcache;

use strict;
use warnings;
use autodie;
use Digest::MD5;
use 5.012_001;
use Data::Dumper qw(Dumper);
use Cache::Memcached;

use constant MEMCACHE_DEBUG => 0;
use constant COMPRESS_TRESH => 10_000;

our $slot    = '_DEFAULT_';
our $servers = ["127.0.0.1:11211"];

our $_class_ttl = {};
our $_class_keys = {};

my $memd;
my $hits = 0;

sub get {
    
    my $self = shift;
    my $key  = shift;
    
    my $slot_plus_key = $slot . '_' . $key;
    
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
    my $class    = shift;
    
    $_class_keys->{$class}->{$key} = 1;
    
    if (exists $_class_ttl->{$class} and $_class_ttl->{$class} > 0) {
        $ttl = $_class_ttl->{$class}
    }
    
    my $slot_plus_key = $slot . '_' . $key;
    $memd->set($slot_plus_key, $contents, $ttl);    
    return;
}

sub delete {
    my $self = shift;
    my $key = shift;
    my $slot_plus_key = $slot . '_' . $key;
    return $memd->delete($slot_plus_key);
}

sub clear {
    my $self = shift;
    my $class = shift;

    if (exists $_class_keys->{$class}) {
        my @keys = $self->class_keys($class);
        foreach my $k (@keys) { 
            my $found = $self->delete($k);
            if (!$found) {
                #warn "$k not found in cache"
            }
            else {
                delete $_class_keys->{$class}->{$k};
            }
        }
        return 1;
    }
    return 0;
}

sub digest {
    my $self = shift;
    my $string = shift;
    my $md5 = Digest::MD5->new;
    $md5->add($string);
    return $md5->hexdigest;
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
    return $memd->stats('misc')->{total}->{curr_items};
}
sub content {}

sub hits {
    my $self = shift;
    return $hits;
}

sub class_keys {
    my $self = shift;
    my $class = shift;
    my @list = ();
    if (exists $_class_keys->{$class}) {
        @list = keys $_class_keys->{$class};
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
    return $slot;
}

# private

sub _connect {
    my $self = shift;
    return new Cache::Memcached {
        'servers'            => $servers,
        'debug'              => MEMCACHE_DEBUG,
        'compress_threshold' => COMPRESS_TRESH,
    };
}

1;
