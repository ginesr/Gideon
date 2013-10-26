package Test::Gideon::DBI::Mock;

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Carp qw(cluck);
use Moose;
use Gideon::DBI;
use Gideon::Error;
use Gideon::Error::DBI;
use Test::MockObject;
use Test::More;
use Carp qw(cluck);

my @known_methods = qw(find_all find delete update function last_inserted_id save remove);

my $times = 0;
my $last_insert = 0;

our $query_str_limit = 50;

BEGIN {
  no warnings 'redefine';
  *Gideon::DBI::last_inserted_id = sub {
      $last_insert++;
      return $last_insert;
  }
}

extends 'Test::Gideon::Results';

sub connect {
    my $self = shift;
    return $self;
}

sub errstr {
    my $self = shift;
    return "This is an error";
}

sub get_info {
    my $self = shift;
    return;
}

sub prepare_cached {
    return shift->prepare(@_)
}

sub prepare {

    my $self  = shift;
    my $query = shift;

    my $candidate_class = $self->find_class_in_stack;
    my $function = $self->find_function_in_stack;
    my $session = $self->get_next_session;
    $times++;

    if ( !$session ) {
        Gideon::Error::DBI->throw("Session exhausted for class $candidate_class called using $function()");
    }

    Gideon::Error::DBI->throw("Can\'t find know class in stack") if not $candidate_class;
    Gideon::Error::DBI->throw("Missing class name in mock, did you mean $candidate_class ?") if not $session->{class};

    if ($candidate_class and $session->{class} ne $candidate_class) {
        Gideon::Error::DBI->throw("You said $session->{class} and $candidate_class was found");
    }

    if ( $query =~ /insert into/i or $query =~ /^update/i or $query =~ /^delete/i ) {
        return $self->prepare_no_fetch($query,$candidate_class,$function);
    }
    if ( $query =~ /select last_insert_id\(\) as last/ or $query =~ /SELECT ROWID as last/ ) {
        return $self->prepare_for_functions($query);
    }

    subtest __PACKAGE__ . " - Subtest $times passed" => sub {
        plan tests => 5;

        my $result = 0;
        my $msg    = 'found session';
        my $left   = $self->count_left;

        if ( $session->{results} and scalar @{$session->{results}} >= 0 ) {
            $result = scalar @{$session->{results}};
        }
        else {
            $msg    = 'session not found';
            $result = -1;
            $self->sessionerrors( $self->sessionerrors + 1 );
        }

        ok( $query, 'query: ' . substr( $query, 0, $query_str_limit ) . ' ...' );
        ok( 1,      "$msg results ($result)" );
        ok( 1,      "sessions left $left" );
        is( $session->{class}, $candidate_class, 'class matches ' . $candidate_class);
        ok( 1,      "function_found $function()" );

    };

    if ( !$session ) {
        Gideon::Error::DBI->throw('Session exhausted');
    }

    my @fields  = $self->_columns_with_table_as_list($session);
    my $colhash = $self->_get_columns_hash( $session->{class} );
    my $sth     = Test::MockObject->new();
    my $bound   = [];

    $sth->{NAME_lc} = [ map { $_ } @fields ];
    $sth->mock(
        'execute',
        sub {
            my $class = shift;
            my @bind  = @_;
            my $total = scalar @{ $session->{results} };
            return $total ? $total : -1;
        }
    );
    $sth->mock(
        'bind_columns',
        sub {
            my $class = shift;
            $bound = [@_];
        }
    );
    $sth->mock(
        'fetch',
        sub {

            my $class = shift;
            my %row;
            my $c = 0;

            if ( scalar @{ $session->{results} } == 0 ) {
                return;
            }

            my $obj = shift @{ $session->{results} };

            die 'result has invalid class' if ref $obj ne $session->{class};

            foreach my $field ( @fields ) {

                my $accessor = $colhash->{$field};
                my $value = $obj->$accessor;

                $row{ $field } = $value;

                if ( ref $bound->[$c] eq 'SCALAR' ) {
                    my $bound = $bound->[$c];
                    $$bound = $value;
                }
                $c++;
            }
            return \%row;
        }
    );
    $sth->mock(
        'finish',
        sub {
            $bound = [];
        }
    );

    return $sth;
}

sub prepare_no_fetch {

    my $self = shift;
    my $query = shift;
    my $class_found = shift;
    my $function = shift;

    my $sth  = Test::MockObject->new();

    $sth->mock(
        'execute',
        sub {
            my $class = shift;
            my @bind;
            
            foreach (@_) {
                $_ = '<_NULL_>' if not defined $_;
                push @bind, $_
            }
            
            subtest __PACKAGE__ . " - Subtest $times passed" => sub {
                plan tests => 5;
        
                ok( $query, 'query: ' . substr( $query, 0, $query_str_limit ) . ' ...' );
                ok( 1, 'no need for session' );
                ok( 1, "class found $class_found" );
                ok( 1, "function found $function()" );
                ok( 1, "params = " . scalar(@bind) . "\n" . join("\n", @bind) );
            };
            
            return 1;
        }
    );

    $sth->mock(
        'finish',
        sub {
            return 1;
        }
    );
    return $sth;
}

sub find_function_in_stack {

    my $self = shift;
    my $callers = 0;
    my $function_found;

    while (my ($package) = caller($callers) ) {
        my %info = &Carp::caller_info($callers);
        if ( exists $info{'sub'} and $info{'sub'} =~ /^Gideon/) {
            foreach my $method (@known_methods) {
                if ( $info{'sub_name'} =~ /$method/ ) {
                    $function_found = $info{'sub_name'};
                    $function_found =~ s/(.*?)(\(.*\))/$1/; # remove params
                    $function_found =~ s/.*\:\:(.*?)/$1/; # remove package name
                }
            }
        }
        $callers ++;
    }
    return $function_found
}

sub find_class_in_stack {

    my $self = shift;
    my $callers = 0;
    my $candidate_class;

    while (my ($package) = caller($callers) ) {
        my %info = &Carp::caller_info($callers);
        if ( exists $info{'sub'} and $info{'sub'} =~ /^Test::Exception/ and $info{'pack'} eq 'main') {
            die 'Use Try::Tiny with this class';
        }
        if ( exists $info{'sub'} and $info{'sub'} =~ /^Gideon/) {
            foreach my $method (@known_methods) {
                if ( $info{'sub_name'} =~ /$method/ ) {
                    my $params = $info{'sub_name'};
                    $params =~ s/(.*?\()(.*)(\)$)/$2/; # extract params
                    next unless $params;
                    my @args = split ',', $params;
                    my $pkg = shift @args;
                    $pkg =~ s/\'//g; # remove single quote from param list
                    $pkg =~ s/(.*?)=HASH.*/$1/g; # remove references for objects
                    $candidate_class = $pkg;
                }
            }
        }
        $callers ++;
    }
    return $candidate_class;
}

sub _columns_with_table_as_list {

    my $self = shift;
    my $session = shift;

    my $class = $session->{class};
    my $meta = $class->get_all_meta;
    my $table = $class->get_store_destination();
    my @columns = ();
    my %ignored = ();

    if ( my $ignore_fields = $session->{ignore} ) {
        %ignored = map {$_=>1} @$ignore_fields;
    }

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( exists $meta->{attributes}->{$attribute}->{column} ) {
            next if exists $ignored{$attribute};
            push @columns, $meta->{attributes}->{$attribute}->{column};
        }
    }

    return map { $table . '.' . $_ } @columns;
}

sub _get_columns_hash {

    my $self    = shift;
    my $class   = shift;
    my $meta    = $class->get_all_meta;
    my $table   = $class->get_store_destination();
    my $hash    = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        my $key = $table . '.' . $class->get_colum_for_attribute($attribute);
        $hash->{$key} = $attribute;
    }

    return $hash;
}


1;
