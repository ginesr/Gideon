
package Gideon::Cache;

use strict;
use warnings;
use autodie;
use Digest::MD5;
use 5.012_001;

our $_cache = {};
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
    if ( my $cached = $_cache->{$key} ) {
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
    $_cache->{$key} = $contents;
    return;
}

sub count {
    my $self = shift;
    return scalar keys %{$_cache};
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

1;
