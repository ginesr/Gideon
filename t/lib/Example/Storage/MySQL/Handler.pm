
package Example::Storage::MySQL::Handler;

use strict;
use warnings;
use DBI;
use Try::Tiny;
use Example::Error::Simple;
use Class::Accessor::Fast qw(moose-like);

has '__dbh' => ( is => 'rw' );

sub new {

    my $self  = shift;
    my $obref = {};

    bless $obref, $self;
    return $obref;
}

sub dbh {

    my $self = shift;
    my $mode = shift;

    if ( $self->__dbh() ) { return $self->__dbh() }

    my $dbh;

    my $dbi_string = '';
    my $user       = '';
    my $pw         = '';

    unless ( $dbh = DBI->connect( $dbi_string, $user, $pw, { RaiseError => 1 } ) ) {
        Example::Error::Simple->throw($DBI::errstr);
    }

    $dbh->{mysql_auto_reconnect} = 1;
    $dbh->do("SET CHARACTER SET utf8");
    $dbh->do("SET NAMES UTF8");

    $self->__dbh($dbh);

    return $dbh;

}

1;
