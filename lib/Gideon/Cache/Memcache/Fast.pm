package Gideon::Cache::Memcache::Fast;

use strict;
use warnings;
use base 'Gideon::Cache::Memcache';
use Cache::Memcached::Fast;

sub _connect {
    my $self = shift;
    return new Cache::Memcached::Fast {
        'servers' => $self->get_servers
    };
}

1;