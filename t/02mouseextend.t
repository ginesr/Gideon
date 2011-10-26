#!/usr/bin/perl

use strict;
use Test::More tests => 6;
use Data::Dumper qw(Dumper);
use DBD::Mock;
use Example::Country;

my $dbh = DBI->connect( 'DBI:Mock:', '', '' ) or die 'Cannot create handle';
my $mock_session = DBD::Mock::Session->new(
    {
        statement    => 'INSERT INTO country ( id) VALUES ( ? )',
        bound_params => [1],
        results      => []
    },
);
$dbh->{mock_session} = $mock_session;

# END Mock --------------------------------------------------------------------

Gideon->register_store( 'master', $dbh );

#using real db w/dbi compatible driver
#Gideon->register_store('master','DBI:mysql:database=test;host=127.0.0.1;port=3306;mysql_enable_utf8=1;mysql_auto_reconnect=1','root','secret');

my $country = Example::Country->new();
$country->name('Argentina');
is( $country->name, 'Argentina', 'Country' );
$country->save();

warn $country->meta->get_attribute('name')->has_column();
warn $country->meta->get_attribute('name')->column();

$country->meta->add_attribute( '_modified' => ( is => 'rw' ) );

$country->meta->add_before_method_modifier(
    'name',
    sub {
        my $self      = shift;
        my $new_value = shift;
        if ($new_value) {
            my $meta      = $self->meta;
            my $attribute = $meta->get_attribute('name');
            my $reader    = $attribute->get_read_method;
            if ( $self->$reader ne $new_value ) {
                $self->_modified( $self->_modified + 1 );
                warn 'cambió!';
            }
        }
    }
);
$country->name('Wohoo');
warn $country->_modified;

#warn Dumper( $hotelinv->meta->get_all_attributes() );
