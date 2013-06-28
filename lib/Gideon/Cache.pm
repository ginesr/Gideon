package Gideon::Cache;

use strict;
use warnings;
use autodie;
use Digest::MD5;
use 5.012_001;
use Data::Dumper qw(Dumper);

our $slot = '_DEFAULT_';
our $_cache = { $slot => {} };
our $_class_ttl = {};
our $_class_keys = {};

my $hits = 0;

sub digest {
    my $self = shift;
    my $string = shift;
    my $md5 = Digest::MD5->new;
    $md5->add($string);
    return $md5->hexdigest;
}

sub get {
    my $self = shift;
    my $key  = shift;
    $self->expire;
    if ( my $cached = $_cache->{$slot}->{$key}->{content} ) {
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
    $_cache->{$slot}->{$key}->{content} = $contents;
    
    if (not exists $_cache->{$slot}->{$key}->{ttl}) {
        if (exists $_class_ttl->{$class} and $_class_ttl->{$class} > 0) {
            $ttl = $_class_ttl->{$class}
        }
        $_cache->{$slot}->{$key}->{ttl} = $ttl;
        $_cache->{$slot}->{$key}->{stamp} = time();
    }
    
    return;
}

sub expire {
    
    my $self = shift;
    my $now = time();

    foreach my $k (keys %{ $_cache->{$slot} }) {
        my $stamp = $_cache->{$slot}->{$k}->{stamp};
        my $ttl = $_cache->{$slot}->{$k}->{ttl};
        my $expire = $stamp + $ttl;

        if ($expire < $now) {
            $self->delete($k);
        }
    }
    return $self;
}

sub clear {
    my $self = shift;
    my $class = shift;

    if (exists $_class_keys->{$class}) {
        my @keys = $self->class_keys($class);
        foreach (@keys) {
            $self->delete($_)
        }
        delete $_class_keys->{$class};
        return 1;
    }
    return 0;
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

sub delete {
    my $self = shift;
    my $key = shift;
    delete $_cache->{$slot}->{$key};
    return 1
}

sub count {
    my $self = shift;
    return scalar keys %{ $_cache->{$slot} };
}

sub content {
    my $self = shift;
    return $_cache->{$slot};
}

sub hits {
    my $self = shift;
    return $hits;
}

sub detect {
    my $self = shift;
    my $key  = shift;
    return exists $_cache->{$slot}->{$key} ? 1 : 0;
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

sub set_servers {
    my $self = shift;
    return $self;
}

1;
