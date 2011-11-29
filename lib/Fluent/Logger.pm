# -*- coding: utf-8; -*-
package Fluent::Logger;

use strict;
use warnings;
use Mouse;

our $VERSION = '0.01';

use IO::Socket::INET;
use IO::Socket::UNIX;
use Data::MessagePack;
use Time::Piece;
use JSON ();
use Carp;

has tag_prefix => (
    is  => "rw",
    isa => "Str",
);

has host => (
    is      => "rw",
    isa     => "Str",
    default => "127.0.0.1",
);

has port => (
    is      => "rw",
    isa     => "Int",
    default => 24224,
);

has socket => (
    is       => "rw",
    isa      => "Str",
    required => 0,
);

has timeout => (
    is      => "rw",
    isa     => 'Num',
    default => 3.0,
);

has buffer_limit => (
    is      => "rw",
    isa     => 'Int',
    default => 8 * 1024 * 1024, # fixme
);

has max_write_retry => (
    is      => "rw",
    isa     => 'Int',
    default => 5,
);

has write_length => (
    is  => "rw",
    isa => 'Int',
    default => 8 * 1024 * 1024,
);

has socket_io => (
    is  => "rw",
    isa => "IO::Socket",
);

has errors => (
    is      => "rw",
    isa     => "ArrayRef",
    default => sub { [] },
);

has prefer_integer => (
    is      => "rw",
    isa     => "Bool",
    default => 1,
);

has packer => (
    is      => "rw",
    isa     => "Data::MessagePack",
    default => sub {
        my $self = shift;
        my $mp   = Data::MessagePack->new;
        $mp->prefer_integer( $self->prefer_integer );
        $mp;
    },
);

no Mouse;

sub BUILD {
    my $self = shift;
    $self->_connect;
}

sub _carp {
    my $self = shift;
    my $msg  = shift;
    chomp $msg;
    carp (
        sprintf "%s %s(%s): %s",
        localtime->strftime("%Y-%m-%dT%H:%M:%S%z"),
        ref $self,
        $self->_connect_info,
        $msg,
    );
}

sub _add_error {
    my $self = shift;
    my $msg  = shift;
    $self->_carp($msg);
    push @{ $self->errors }, $msg;
}

sub errstr {
    my $self = shift;
    return join ("\n", @{ $self->errors });
}

sub _connect_info {
    my $self = shift;
    $self->socket || sprintf "%s:%d", $self->host, $self->port;
}

sub _connect {
    my $self = shift;

    return if $self->socket_io;

    my $sock = defined $self->socket
             ? IO::Socket::UNIX->new( Peer => $self->socket )
             : IO::Socket::INET->new(
                 PeerAddr  => $self->host,
                 PeerPort  => $self->port,
                 Proto     => 'tcp',
                 Timeout   => $self->timeout,
                 ReuseAddr => 1,
             );
    if (!$sock) {
        $self->_add_error($!);
        return;
    }
    $self->socket_io($sock);
}

sub close {
    my $self = shift;

    my $socket = delete $self->{socket_io};
    $socket->close if $socket;
}

sub post {
    my($self, $tag, $msg) = @_;

    $self->_post( $tag || "", $msg, time() );
}

sub post_with_time {
    my ($self, $tag, $msg, $time) = @_;

    $self->_post( $tag || "", $msg, $time );
}

sub _post {
    my ($self, $tag, $msg, $time) = @_;

    if (ref $msg ne "HASH") {
        $self->_add_error("message '$msg' must be a HashRef");
        return;
    }

    $tag = join('.', $self->tag_prefix, $tag) if $self->tag_prefix;
    my $data = [ "$tag", int $time, $msg ];

    if (! $self->socket_io) {
        $self->_connect or do {
            $self->_add_error("Cannot send data: " . JSON::encode_json($data));
            return;
        };
    }

    $self->_send($data);
}

sub _send {
    my ($self, $data) = @_;

    $self->packer->prefer_integer( $self->prefer_integer );
    my $mpdata = $self->packer->pack($data);
    my $length = length($mpdata);
    my $retry  = my $written = 0;

    local $SIG{"PIPE"} = sub { die $! };
 TRY:
    for my $try (1, 2) {
        eval {
            while ($written < $length) {
                my $nwrite
                    = $self->socket_io->syswrite($mpdata, $self->write_length, $written);

                unless ($nwrite) {
                    if ($retry > $self->max_write_retry) {
                        die "failed write retry; max write retry count. $!";
                    }
                    $retry++;
                }
                $written += $nwrite;
            }
        };
        if ($@) {
            my $error = $@;
            $self->close;
            $self->_carp("Trying reconnect($try): $error");
            $self->_connect or do {
                $self->_add_error(
                    "Cannot send data: " . JSON::encode_json($data) . " $error"
                );
                return;
            };
            $self->_carp("Successfully reconnected!");
            next TRY; # retry
        }
        last TRY; # ok
    }

    return $written;
}

1;
__END__

=encoding utf-8

=head1 NAME

Fluent::Logger - A structured event logger for Fluent

=head1 SYNOPSIS

    use Fluent::Logger;
    
    my $logger = Fluent::Logger->new(host => '127.0.0.1', port => 24224);
    $logger->post("myapp.access", { "agent" => "foo" });
    # output: myapp.access {"agent":"foo"}
    
    my $logger = Fluent::Logger->new(tag_prefix => 'myapp', host => '127.0.0.1', port => 24224);
    $logger->post("access", { "agent" => "foo" });
    # output: myapp.access {"agent":"foo"}

=head1 WARNING

B<This software is under the heavy development and considered ALPHA
quality till the version hits v1.0.0. Things might be broken, not all
features have been implemented, and APIs will be likely to change. YOU
HAVE BEEN WARNED.>

=head2 TODO

=over 4

=item * buffering and pending

=item * timeout, reconnect

=item * write pod

=item * test cases

=back

=head1 DESCRIPTION

Fluent::Logger is a structured event logger for Fluent.

=head1 METHODS

=over 4

=item B<new>(%args)

create new logger instance.

%args:

    tag_prefix     => 'Str':  optional
    host           => 'Str':  default is '127.0.0.1'
    port           => 'Int':  default is 24224
    timeout        => 'Num':  default is 3.0
    socket         => 'Str':  default undef (e.g. "/var/run/fluent/fluent.sock")
    prefer_integer => 'Bool': default 1 (set to Data::MessagePack->prefer_integer)

=item B<post>($tag:Str, $msg:HashRef)

send message to fluent server with tag.

=item B<post_with_time>($tag:Str, $msg:HashRef, $time:Int)

send message to fluent server with tag and time.

=item B<close>()

close connection.

=item B<errstr>

return error message.

  $logger->post( info => { "msg": "test" } )
      or die $logger->errstr;

=back

=head1 AUTHOR

HIROSE Masaaki E<lt>hirose31 _at_ gmail.comE<gt>

Shinichiro Sei E<lt>sei _at_ kayac.comE<gt>

FUJIWARA Shunichiro E<lt>fujiwara _at_ cpan.orgE<gt>

=head1 REPOSITORY

L<https://github.com/fluent/fluent-logger-perl>

    git clone git://github.com/fluent/fluent-logger-perl.git

patches and collaborators are welcome.

=head1 SEE ALSO

L<http://fluent.github.com/>

=head1 COPYRIGHT & LICENSE

Copyright HIROSE Masaaki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
