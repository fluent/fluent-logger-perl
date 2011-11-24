# -*- coding: utf-8; -*-
package Fluent::Logger;

use strict;
use warnings;
use Mouse;

our $VERSION = '0.01_01';

use IO::Socket::INET;
use IO::Socket::UNIX;
use Data::MessagePack;

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

no Mouse;

sub BUILD {
    my $self = shift;
    $self->_connect;
}

sub _add_error {
    my $self = shift;
    my $msg  = shift;
    push @{ $self->errors }, $msg;
}

sub errstr {
    my $self = shift;
    return join ("\n", @{ $self->errors });
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
        $self->_add_error("message must be HASHREF");
        return;
    }

    $self->_connect or return
        unless $self->socket_io;

    $tag = join('.', $self->tag_prefix, $tag) if $self->tag_prefix;

    $self->_send(
        Data::MessagePack->pack([ "$tag", int $time, $msg ])
    );
}

sub _send {
    my ($self, $data) = @_;

    my $length = length($data);
    my $retry = my $written = 0;

    local $SIG{"PIPE"} = sub {
        $self->close;
        die $!;
    };

    eval {
        while ($written < $length) {
            my $nwrite
                = $self->socket_io->syswrite($data, $self->write_length, $written);

            unless ($nwrite) {
                if ($retry > $self->max_write_retry) {
                    die 'failed write retry; max write retry count';
                }
                $retry++;
            }
            $written += $nwrite;
        }
    };
    if ($@) {
        $self->_add_error($@);
        return;
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

    tag_prefix  => 'Str': optional
    host        => 'Str': default is '127.0.0.1'
    port        => 'Int': default is 24224
    timeout     => 'Num': default is 3.0
    socket      => 'Str': default undef (e.g. "/var/run/fluent/fluent.sock")

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

=head1 REPOSITORY

L<https://github.com/hirose31/fluent-logger-perl>

    git clone git://github.com/hirose31/fluent-logger-perl.git

patches and collaborators are welcome.

=head1 SEE ALSO

L<http://fluent.github.com/>

=head1 COPYRIGHT & LICENSE

Copyright HIROSE Masaaki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
