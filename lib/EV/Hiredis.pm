package EV::Hiredis;
use strict;
use warnings;

use EV;

BEGIN {
    use XSLoader;
    our $VERSION = '0.01';
    XSLoader::load __PACKAGE__, $VERSION;
}

sub new {
    my ($class, %args) = @_;

    my $loop = $args{loop} || EV::default_loop;
    my $self = $class->_new($loop);

    $self->on_error($args{on_error} || sub { die @_ });
    $self->on_connect($args{on_connect}) if $args{on_connect};

    if (exists $args{host}) {
        $self->connect($args{host}, defined $args{port} ? $args{port} : 6379);
    }
    elsif (exists $args{path}) {
        $self->connect_unix($args{path});
    }

    $self;
}

1;

=head1 NAME

EV::Hiredis - module abstract

=cut
