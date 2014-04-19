package Gideon::Cache::Memcache::Fast;

use strict;
use warnings;
use base 'Gideon::Cache::Memcache';
use Cache::Memcached::Fast;

use constant COMPRESS_TRESH => 10_000;
our $servers = ["127.0.0.1:11211"];

sub _connect {
    my $self = shift;
    return new Cache::Memcached::Fast {
        'servers'            => $servers,
        'compress_threshold' => COMPRESS_TRESH,
    };
}

1;