
package Example::Error::Simple;

use strict;

sub throw {

    my $class = shift;
    my $msg   = shift;

    my ( $pkg, $file, $line ) = caller(1);

    my $self = { pkg => $pkg, msg => $msg };
    bless $self, $class;
    die $self;

}

1;
