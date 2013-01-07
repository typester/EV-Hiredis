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
}

1;

=head1 NAME

EV::Hiredis - module abstract

=cut
