
package Example::Storage::DBI;

use strict;
use warnings;
use Example::Storage::MySQL::Handler;
use base qw(Gideon::DBI);

sub handler {

    my $self = shift;
    my $type = shift;

    return Example::Storage::MySQL::Handler->new->dbh($type);

}

1;
