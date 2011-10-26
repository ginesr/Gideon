
package Example::Person;

use strict;
use warnings;
use Collections::Ordered;
use Example::Storage::DBI;
use base qw(Example::Storage::DBI);

meta {
    table      => 'person',
    attributes => {
        'id' => { isa => 'Num', required => 1, column => 'person_id' },
        'name'    => { isa => 'Str', column => 'person_name' },
        'city'    => { isa => 'Str', column => 'person_city' },
        'country' => { isa => 'Str', column => 'person_country', default => 'US' },
        'type'    => { isa => 'Str', column => 'person_type' },
    },
    has => { 'contacts' => { isa => 'Collections::Ordered' }, }
};

1;