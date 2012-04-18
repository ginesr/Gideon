#perl

use lib './lib/';
use strict;
use Test::More tests => 14;
use Gideon;

my $one = Gideon->check_for_config_in_params( name => 1 );
is( $one, undef, 'One param. No config in params' );

my $no_pair = Gideon->check_for_config_in_params('name');
is( $no_pair, undef, 'One param not pairs. No config in params' );

my $no_pair_p = Gideon->check_for_config_in_params('name', {});
is( $no_pair_p, undef, 'One param not pairs. Config is present' );

my $just_config = Gideon->check_for_config_in_params( { this => 'that' } );
is( $just_config, 1, 'Just config is present' );

my $undef = Gideon->check_for_config_in_params(undef);
is( $undef, undef, 'No params. No config in params' );

my $undef_p = Gideon->check_for_config_in_params( undef, { limit => 1 } );
is( $undef_p, 1, 'No params. Config present' );

my $one_p_ref = Gideon->check_for_config_in_params( name => { like => 'foo'} );
is( $one_p_ref, undef, 'One param with ref options. No config' );

my $one_p_ref_c = Gideon->check_for_config_in_params( name => { like => 'foo'}, { test => 1 } );
is( $one_p_ref_c, 1, 'One param with ref options. Config is present' );

my $one_p = Gideon->check_for_config_in_params( name => 1, { limit => 1 } );
is( $one_p, 1, 'Params' );

my $two = Gideon->check_for_config_in_params( name => 1, value => 'a' );
is( $two, undef, 'No params' );

my $two_p = Gideon->check_for_config_in_params( name => 1, value => 'a', {} );
is( $two_p, 1, 'Two pairs with config' );

my $two_ref =
  Gideon->check_for_config_in_params( name => 1, value => { like => 'a' } );
is( $two_ref, undef, 'Two params one w/options' );

my $two_ref_p = Gideon->check_for_config_in_params(
    name  => 1,
    value => { like => 'a' },
    { limit => 1 }
);
is( $two_ref_p, 1, 'Two params one w/options and config is present' );

my $two_ref_c = Gideon->check_for_config_in_params(
    name  => { eq => 'bar' },
    value => { like => 'a' },
    { limit => 1 }
);
is( $two_ref_c, 1, 'Two ref params. Config is present' );
