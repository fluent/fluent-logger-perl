# -*- coding: utf-8; -*-
package Fluent::Logger;

use strict;
use warnings;

our $VERSION = '0.18';

use IO::Socket::INET;
use IO::Socket::UNIX;
use Data::MessagePack;
use Time::Piece;
use Carp;
use Scalar::Util qw/ refaddr /;
use Time::HiRes qw/ time /;

use constant RECONNECT_WAIT           => 0.5;
use constant RECONNECT_WAIT_INCR_RATE => 1.5;
use constant RECONNECT_WAIT_MAX       => 60;
use constant RECONNECT_WAIT_MAX_COUNT => 12;

use constant MP_HEADER_3ELM_ARRAY => "\x93";
use constant MP_HEADER_EVENT_TIME => "\xd7\x00";

use subs 'prefer_integer';

use Class::Tiny +{
    tag_prefix => sub {},
    host => sub { "127.0.0.1" },
    port => sub { 24224 },
    socket => sub {},
    timeout => sub { 3.0 },
    buffer_limit => sub { 8 * 1024 * 1024 }, # fixme
    buffer_overflow_handler => sub { undef },
    truncate_buffer_at_overflow => sub { 0 },
    max_write_retry => sub { 5 },
    write_length => sub { 8 * 1024 * 1024 },
    socket_io => sub {},
    errors => sub { [] },
    prefer_integer => sub { 1 },
    packer => sub {
        my $self = shift;
        my $mp   = Data::MessagePack->new;
        $mp->prefer_integer( $self->prefer_integer );
        $mp;
    },
    pending => sub { "" },
    connect_error_history => sub { +[] },
    owner_pid => sub {},
    event_time => sub { 0 },
};

sub BUILD {
    my $self = shift;
    $self->_connect;
}

sub prefer_integer {
    my $self = shift;

    if (@_) {
        $self->{prefer_integer} = shift;
        $self->packer->prefer_integer( $self->prefer_integer );
    } elsif ( exists $self->{prefer_integer} ) {
        return $self->{prefer_integer};
    } else {
        my $defaults = Class::Tiny->get_all_attribute_defaults_for( ref $self );
        return $self->{prefer_integer} = $defaults->{prefer_integer}->();
    }
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
    my $self  = shift;
    my $force = shift;

    return if $self->socket_io && !$force;

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
        $self->_add_error("Can't connect: $!");
        push @{ $self->connect_error_history }, time;
        if (@{ $self->connect_error_history } > RECONNECT_WAIT_MAX_COUNT) {
            shift @{ $self->connect_error_history };
        }
        return;
    }
    $self->connect_error_history([]);
    $self->owner_pid($$);
    $self->socket_io($sock);
}

sub close {
    my $self = shift;

    if ( length $self->{pending} ) {
        $self->_carp("flushing pending data on close");
        $self->_connect unless $self->socket_io;
        my $written = eval {
            $self->_write( $self->{pending} );
        };
        if ($@ || !$written) {
            my $size = length $self->{pending};
            $self->_carp("Can't send pending data. LOST $size bytes.: $@");
        }
        else {
            $self->_carp("pending data was flushed successfully");
        }
    };
    $self->{pending} = "";
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

sub _pack_time {
    my ($self, $time) = @_;

    if ($self->event_time) {
        my $time_i  = int $time;
        my $nanosec = int(($time - $time_i) * 10 ** 9);
        return MP_HEADER_EVENT_TIME . pack("NN", $time_i, $nanosec);
    } else {
        return $self->packer->pack(int $time);
    }
}

sub _post {
    my ($self, $tag, $msg, $time) = @_;

    if (ref $msg ne "HASH") {
        $self->_add_error("message '$msg' must be a HashRef");
        return;
    }

    $tag = join('.', $self->tag_prefix, $tag) if $self->tag_prefix;
    my $p = $self->packer;
    $self->_send(
        MP_HEADER_3ELM_ARRAY . $p->pack($tag) . $self->_pack_time($time) . $p->pack($msg)
    );
}

sub _send {
    my ($self, $data) = @_;

    my $prev_size = length($self->{pending});
    my $current_size = length($data);
    $self->{pending} .= $data;

    my $errors = @{ $self->connect_error_history };
    if ( $errors && length $self->pending <= $self->buffer_limit )
    {
        my $suppress_sec;
        if ( $errors < RECONNECT_WAIT_MAX_COUNT ) {
            $suppress_sec = RECONNECT_WAIT * (RECONNECT_WAIT_INCR_RATE ** ($errors - 1));
        }
        else {
            $suppress_sec = RECONNECT_WAIT_MAX;
        }
        if ( time - $self->connect_error_history->[-1] < $suppress_sec ) {
            return;
        }
    }

    # fork safe
    if (!$self->socket_io || $self->owner_pid != $$) {
        $self->_connect(1);
    }

    my $written;
    eval {
        $written = $self->_write( $self->{pending} );
        $self->{pending} = "";
    };
    if ($@) {
        my $error = $@;
        $self->_add_error("Cannot send data: $error");
        delete $self->{socket_io};
        if ( length($self->{pending}) > $self->buffer_limit ) {
            if ( defined $self->buffer_overflow_handler ) {
                $self->_call_buffer_overflow_handler();
                $self->{pending} = "";
            } elsif ( $self->truncate_buffer_at_overflow ) {
                substr($self->{pending}, $prev_size, $current_size, "");
            }
        }
        return;
    }
    $written;
}

sub _call_buffer_overflow_handler {
    my $self = shift;
    if (my $handler = $self->buffer_overflow_handler) {
        eval {
            $handler->($self->{pending});
        };
        if (my $error = $@) {
            $self->_add_error("Can't call buffer overflow handler: $error");
        }
    }
}

sub _write {
    my $self = shift;
    my $data = shift;
    my $length = length($data);
    my $retry  = my $written = 0;

    local $SIG{"PIPE"} = sub { die $! };

    while ($written < $length) {
        my $nwrite
            = $self->socket_io->syswrite($data, $self->write_length, $written);

        if (!$nwrite) {
            if ($retry > $self->max_write_retry) {
                die "failed write retry; max write retry count. $!";
            }
            $retry++;
        } else {
            $written += $nwrite;
        }
    }
    $written;
}

sub DEMOLISH {
    my $self = shift;
    $self->close;
}


1;
__END__

=encoding utf-8

=head1 NAME

Fluent::Logger - A structured event logger for Fluent

=head1 SYNOPSIS

    use Fluent::Logger;
    
    my $logger = Fluent::Logger->new(
        host => '127.0.0.1',
        port => 24224,
    );
    $logger->post("myapp.access", { "agent" => "foo" });
    # output: myapp.access {"agent":"foo"}
    
    my $logger = Fluent::Logger->new(
        tag_prefix => 'myapp',
        host       => '127.0.0.1',
        port       => 24224,
    );
    $logger->post("access", { "agent" => "foo" });
    # output: myapp.access {"agent":"foo"}

=head1 DESCRIPTION

Fluent::Logger is a structured event logger for Fluent.

=head1 METHODS

=over 4

=item B<new>(%args)

create new logger instance.

%args:

    tag_prefix                  => 'Str':  optional
    host                        => 'Str':  default is '127.0.0.1'
    port                        => 'Int':  default is 24224
    timeout                     => 'Num':  default is 3.0
    socket                      => 'Str':  default undef (e.g. "/var/run/fluent/fluent.sock")
    prefer_integer              => 'Bool': default 1 (set to Data::MessagePack->prefer_integer)
    event_time                  => 'Bool': default 0 (timestamp includes nanoseconds, supported by fluentd >= 0.14.0)
    buffer_limit                => 'Int':  defualt 8388608 (8MB)
    buffer_overflow_handler     => 'Code': optional
    truncate_buffer_at_overflow => 'Bool': default 0

=over 4

=item buffer_overflow_handler

You can inject your own custom coderef to handle buffer overflow in the event of connection failure.
This will mitigate the loss of data instead of simply throwing data away.

Your proc should accept a single argument, which will be the internal buffer of messages from the logger.
A typical use-case for this would be writing to disk or possibly writing to Redis.

=item truncate_buffer_at_overflow

When truncate_buffer_at_overflow is true and pending buffer size is larger than buffer_limit, post() returns undef.

Pending buffer still be kept, but last message passed to post() is not sent and not appended to buffer. You may handle the message by other method.

=back

=item B<post>($tag:Str, $msg:HashRef)

Send message to fluent server with tag.

Return bytes length of written messages.

If event_time is set to true, log's timestamp includes nanoseconds.

=item B<post_with_time>($tag:Str, $msg:HashRef, $time:Int|Float)

Send message to fluent server with tag and time.

If event_time is set to true, $time argument accepts Float value (such as Time::HiRes::time()).

=item B<close>()

close connection.

If the logger has pending data, flushing it to server on close.

=item B<errstr>

return error message.

  $logger->post( info => { "msg": "test" } )
      or die $logger->errstr;

=back

=head1 AUTHOR

HIROSE Masaaki E<lt>hirose31 _at_ gmail.comE<gt>

Shinichiro Sei E<lt>sei _at_ kayac.comE<gt>

FUJIWARA Shunichiro E<lt>fujiwara _at_ cpan.orgE<gt>

=head1 THANKS TO

Kazuki Ohta

FURUHASHI Sadayuki

lestrrat

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
