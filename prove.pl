#!/usr/bin/env perl

use strict;
use warnings;
use Test::Harness;
use File::Basename qw(dirname);
use Time::HiRes qw(gettimeofday tv_interval);

# Used to run all tests without having to run prove scripts from command line

my $path  = dirname(__FILE__);

chdir $path;

my @tests = glob( 't/*.t' );
my $t0    = [gettimeofday];

my $harness = TAP::Harness->new;
my $aggregator = $harness->runtests(@tests);

# TODO: add option to save results to file

if ($aggregator) {

    my $passed = $aggregator->passed;
    my $failed = $aggregator->failed;
    my $errors = $aggregator->has_errors;

    # TODO: do something with each result type

}

my $elapsed = tv_interval ( $t0 );
print "Done $elapsed secs.\n";
