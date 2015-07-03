package Gideon::Cache;

use Moose;
use Gideon::Error;
use Data::Dumper qw(Dumper);
use MooseX::ClassAttribute;

use constant CACHE_DEFAULT_TTL => 600; # default expire seconds

has 'module' => ( is => 'rw', isa => 'Str' );
has 'ttl' => ( is => 'rw', isa => 'Maybe[Num]', lazy => 1, default => CACHE_DEFAULT_TTL);
has 'is_enabled' => ( is => 'rw', isa => 'Bool', default => 1 );
class_has 'who' => ( is => 'rw', isa => 'Str' );

sub register {
    my $self = shift;
    my $module = shift || die;
    $self->module($module);
    return 1;
}

sub is_registered {
    my $self = shift;
    return ($self->module) ? 1 : 0;
}

sub store {

    my $self = shift;
    my $key = shift;
    my $what = shift;
    my $class = shift;

    return if $self->is_enabled == 0;
    my $secs = $self->ttl;

    $class = $self->who if not $class;

    my $module = $self->get_module;
    return $module->set( $key, $what, $secs, $class);

}

sub clear {
    my $self = shift;
    my $class = shift;
    return if $self->is_enabled == 0;
    my $module = $self->get_module;
    return $module->clear( $class );
}

sub lookup {
    my $self = shift;
    my $key = shift;
    return if $self->is_enabled == 0;
    my $module = $self->get_module;
    return $module->get($key);
}

sub disable {
    my $self = shift;
    $self->is_enabled(0)
}

sub enable {
    my $self = shift;
    $self->is_enabled(1)
}

sub get_module {
    my $self = shift;
    if ($self->is_registered) {
        return $self->module
    }
    return;
}

sub signature {
    my $self = shift;
    my $pkg = $self->who;
    return $pkg . '_' . $pkg->storage->id;
}

__PACKAGE__->meta->make_immutable();
no Moose;
1;