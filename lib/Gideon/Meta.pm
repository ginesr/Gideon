package Gideon::Meta;

use Moose;
use Gideon::Error;
use Data::Dumper qw(Dumper);
use MooseX::ClassAttribute;

class_has 'who' => ( is => 'rw', isa => 'Str' );
has 'metadata_cache' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );

sub check_meta {

    my $self      = shift;
    my $attribute = shift;
    my $meta      = $self->get_all_meta;

    unless ( exists $meta->{attributes}->{$attribute} ) {
        Gideon::Error->throw("invalid meta data '$attribute' for class " . $self->who);
    }

    return $meta->{attributes}->{$attribute};
}

sub get_alias_for_attribute {
    my $self      = shift;
    my $attribute = shift || die;
    return $self->get_value_for_attribute_key($attribute,'alias');
}

sub get_column_for_attribute {
    my $self      = shift;
    my $attribute = shift || die;
    return $self->get_value_for_attribute_key($attribute,'column');
}

sub get_value_for_attribute_key {

    my $self      = shift;
    my $attribute = shift;
    my $key       = shift;
    my $meta      = $self->get_all_meta;

    if ( exists $meta->{attributes}->{$attribute} ) {
        if ( exists $meta->{attributes}->{$attribute}->{$key} ) {
            return $meta->{attributes}->{$attribute}->{$key};
        }
    }
    return;

}

sub get_key_columns_hash {
    my $self = shift;
    return $self->get_columns_hash('filter_keys');
}

sub get_columns_hash {

    my $self    = shift;
    my $options = shift || '';
    my $meta    = $self->get_all_meta;
    my $hash    = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( $options =~ /filter_keys/ ) {
            next unless defined $meta->{attributes}->{$attribute}->{primary_key};
        }
        $hash->{$attribute} = $self->get_column_for_attribute($attribute);
    }

    return $hash;
}

sub get_attributes_from_meta {

    my $self = shift;
    my $meta = $self->get_all_meta;

    my @map = map { $_ } ( keys %{ $meta->{attributes} } );
    return wantarray ? @map : \@map;
}


sub get_attribute_for_column {

    my $self   = shift;
    my $column = shift;
    my $meta   = $self->get_all_meta;

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        my $val = $self->get_column_for_attribute($attribute);
        if ( $column and $val and ( $val eq $column ) ) {
            return $attribute;
        }
    }

    return undef;
}


sub get_attribute_for_alias {

    my $self   = shift;
    my $column = shift;
    my $meta   = $self->get_all_meta;

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( $column and $self->get_alias_for_attribute($attribute) eq $column ) {
            return $attribute;
        }
    }

    return undef;
}

sub get_serial_columns_hash {

    my $self = shift;
    my $meta = $self->get_all_meta;
    my $hash = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        next unless exists $meta->{attributes}->{$attribute}->{serial};
        next unless defined $meta->{attributes}->{$attribute}->{serial};
        $hash->{$attribute} = $self->get_column_for_attribute($attribute);
    }

    return scalar keys %{$hash} == 1 ? $hash : undef;
}

sub get_primary_key_hash {

    my $self = shift;
    my $meta = $self->get_all_meta;
    my $hash = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        next unless exists $meta->{attributes}->{$attribute}->{primary_key};
        next unless defined $meta->{attributes}->{$attribute}->{primary_key};
        $hash->{$attribute} = $attribute;
    }

    return scalar keys %{$hash} == 1 ? $hash : undef;

}

sub get_serial_attr_hash {

    my $self  = shift;
    my $meta  = $self->get_all_meta;
    my $hash  = {};

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        next unless exists $meta->{attributes}->{$attribute}->{primary_key};
        next unless defined $meta->{attributes}->{$attribute}->{serial};
        $hash->{$attribute} = $attribute;
    }

    return scalar keys %{$hash} == 1 ? $hash : undef;

}

sub get_serial_attr {
    my $self = shift;
    if (my $serials = $self->get_serial_attr_hash) {
        my $attr;
        foreach (sort keys %{ $serials }) {
            $attr = $_;
            last;
        }
        return $attr;
    }
}

sub get_columns_from_meta {

    my $self = shift;

    my $meta = $self->get_all_meta;
    my @columns = ();

    foreach my $attribute ( keys %{ $meta->{attributes} } ) {
        if ( exists $meta->{attributes}->{$attribute}->{column} ) {
            push @columns, $meta->{attributes}->{$attribute}->{column};
        }
    }

    return wantarray ? @columns : \@columns;

}

sub get_all_meta {

    my $self       = shift;
    my $meta       = $self->who->meta;
    my $cache_meta = {};

    if (my $cached_data = $self->metadata_cache->{$self->who}) {
        return $cached_data;
    }

    for my $attribute (
        map { $meta->get_attribute($_) }
        sort $meta->get_attribute_list
      ) {

        my $name = $attribute->name;
        my $meta_attr = {};

        if ( $name =~ /^\_/ ) {
            next;
        }

        if ( ref($attribute) !~ /Gideon::Meta/ ) {
            next;
        }

        foreach my $internal ('primary_key','column','alias','serial') {
            if ( $attribute->can($internal) ) {
                if (defined $attribute->$internal) {
                    $meta_attr->{$internal} = $attribute->$internal
                }
            }
        }

        if ($attribute->is_lazy) {
            $meta_attr->{lazy} = 1;
        }

        $cache_meta->{$self->who}->{attributes}->{$name} = $meta_attr;
    }

    $self->metadata_cache($cache_meta);

    return $cache_meta->{$self->who};
}

sub map_args_with_alias {
    my $self = shift;
    my $args  = shift;
    return $self->map_args_with_metadata($args,'get_alias_for_attribute');
}

sub map_args_with_column {
    my $self = shift;
    my $args  = shift;
    return $self->map_args_with_metadata($args,'get_column_for_attribute');
}

sub map_args_with_metadata {

    my $self   = shift;
    my $args   = shift;
    my $getter = shift;
    my $map    = {};
    my $pkg    = $self->who;

    foreach my $arg ( keys %{$args} ) {
        if ($arg eq '-or' and ref $args->{$arg} eq 'HASH' ) {
            foreach my $attr ( keys %{ $args->{$arg} } ) {
                if ( my $col = $self->$getter($attr)) {
                    $map->{$arg}{$col} = $attr;
                    next
                }
                Gideon::Error->throw("invalid argument $attr inside $arg for $pkg");
            }
            next
        }
        if ( my $col = $self->$getter($arg)) {
            $map->{$col} = $arg;
            next
        }
        Gideon::Error->throw('invalid argument ' . $arg . ' for ' . $pkg);
    }

    return $map

}

__PACKAGE__->meta->make_immutable();
no Moose;
1;
