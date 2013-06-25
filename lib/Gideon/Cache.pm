package Gideon::Cache;

use strict;
use warnings;
use autodie;
use Digest::MD5;
use 5.012_001;
use Data::Dumper qw(Dumper);

our $_cache = {};
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
    if ( my $cached = $_cache->{$key}->{content} ) {
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
    $_cache->{$key}->{content} = $contents;
    
    if (not exists $_cache->{$key}->{ttl}) {
        if (exists $_class_ttl->{$class} and $_class_ttl->{$class} > 0) {
            $ttl = $_class_ttl->{$class}
        }
        $_cache->{$key}->{ttl} = $ttl;
        $_cache->{$key}->{stamp} = time();
    }
    
    return;
}

sub expire {
    
    my $self = shift;
    my $now = time();

    foreach my $k (keys $_cache) {
        my $stamp = $_cache->{$k}->{stamp};
        my $ttl = $_cache->{$k}->{ttl};
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
    delete $_cache->{$key};
    return 1
}

sub count {
    my $self = shift;
    return scalar keys %{$_cache};
}

sub content {
    my $self = shift;
    return $_cache;
}

sub hits {
    my $self = shift;
    return $hits;
}

sub detect {
    my $self = shift;
    my $key  = shift;
    return exists $_cache->{$key} ? 1 : 0;
}

sub add_class_ttl {
    my $self = shift;
    my $class = shift || die 'no class specified';
    my $ttl = shift || 1;
    $_class_ttl->{$class} = $ttl;
    return $self;
}

1;
