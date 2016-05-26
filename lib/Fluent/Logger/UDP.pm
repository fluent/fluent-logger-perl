package Fluent::Logger::UDP;

use strict;
use warnings;

use IO::Socket::INET;
use Time::Piece;
use Carp;
use Scalar::Util qw/ refaddr /;
use Time::HiRes qw/ time /;

use Class::Tiny +{
    host      => sub { "127.0.0.1" },
    port      => sub { 5160 },
    socket_io => sub {},
    owner_pid => sub {},
};

sub BUILD {
    my $self = shift;
    $self->_connect;
}

sub _connect {
    my $self  = shift;
    my $force = shift;

    return if $self->{socket_io} && !$force;

    my $sock = IO::Socket::INET->new(
        PeerAddr  => $self->host,
        PeerPort  => $self->port,
        Proto     => "udp",
    );
    if (!$sock) {
        $self->_carp("Can't create socket: $!");
        return;
    }
    $self->{owner_pid} = $$;
    $self->{socket_io} = $sock;
}

sub _carp {
    my $self = shift;
    my $msg  = shift;
    chomp $msg;
    carp (
        sprintf "%s %s[%s](%s): %s",
        localtime->strftime("%Y-%m-%dT%H:%M:%S%z"),
        ref $self,
        refaddr $self,
        $self->_connect_info,
        $msg,
    );
}

sub _connect_info {
    my $self = shift;
    $self->{socket} || sprintf "%s:%d", $self->host, $self->port;
}

sub post {
    my ($self, $msg) = @_;
    if (ref $msg) {
        $self->_carp("message '$msg' must be a Scalar");
        return;
    }

    # fork safe
    if (!$self->{socket_io} || $self->{owner_pid} != $$) {
        $self->_connect(1);
    }
    my $written = 0;
    eval {
        local $SIG{"PIPE"} = sub { die $! };
        my $length = length($msg);
        while ($written < $length) {
            my $nwrite
                = $self->socket_io->syswrite($msg, $length, $written);
            if (!$nwrite) {
                die "failed to write. $!";
            } else {
                $written += $nwrite;
            }
        }
    };
    if ($@ || !$written) {
        my $error = $@;
        $self->_carp("Cannot send data: $error");
        delete $self->{socket_io};
    }
    $written;
}

1;

__END__

=encoding utf-8

=head1 NAME

Fluent::Logger::UDP - A event logger for Fluentd in_udp

=head1 SYNOPSIS

    use Fluent::Logger::UDP;

    my $logger = Fluent::Logger::UDP->new(
        host => '127.0.0.1',
        port => 5160,
    );
    $logger->post('{"foo":"bar"}'); # must be a scalar

=head1 DESCRIPTION

Fluent::Logger::UDP is a event logger for Fluentd in_udp.

=head1 METHODS

=over 4

=item B<new>(%args)

create a new logger instance.

%args:

    host => 'Str':  default is '127.0.0.1'
    port => 'Int':  default is 5160

=item B<post>($msg:Str)

Send a message to in_udp.

Return bytes length of written messages.

=back

=head1 AUTHOR

FUJIWARA Shunichiro E<lt>fujiwara _at_ cpan.orgE<gt>

=head1 REPOSITORY

L<https://github.com/fluent/fluent-logger-perl>

    git clone git://github.com/fluent/fluent-logger-perl.git

patches and collaborators are welcome.

=head1 SEE ALSO

L<http://fluent.github.com/>

=head1 COPYRIGHT & LICENSE

Copyright FUJIWARA Shunichiro

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
