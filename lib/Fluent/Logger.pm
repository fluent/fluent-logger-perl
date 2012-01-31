# -*- coding: utf-8; -*-
package Fluent::Logger;

use strict;
use warnings;
use Mouse;

our $VERSION = '0.03';

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
    trigger => sub {
        my ($self, $new_value) = @_;
        $self->packer->prefer_integer( $new_value );
    }
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

has pending => (
    is      => "rw",
    isa     => "Str",
    default => "",
);

has connect_error_history => (
    is      => "rw",
    isa     => "ArrayRef",
    default => sub { +[] },
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
        $self->_add_error("Can't connect: $!");
        push @{ $self->connect_error_history }, time;
        if (@{ $self->connect_error_history } > RECONNECT_WAIT_MAX_COUNT) {
            shift @{ $self->connect_error_history };
        }
        return;
    }
    $self->connect_error_history([]);
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

sub _post {
    my ($self, $tag, $msg, $time) = @_;

    if (ref $msg ne "HASH") {
        $self->_add_error("message '$msg' must be a HashRef");
        return;
    }

    $tag = join('.', $self->tag_prefix, $tag) if $self->tag_prefix;

    my $data = $self->packer->pack([ "$tag", int $time, $msg ]);

    $self->_send($data);
}

sub _send {
    my ($self, $data) = @_;

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

    unless ($self->socket_io) {
        $self->_connect or return;
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
    }
    $written;
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

        unless ($nwrite) {
            if ($retry > $self->max_write_retry) {
                die "failed write retry; max write retry count. $!";
            }
            $retry++;
        }
        $written += $nwrite;
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

    tag_prefix     => 'Str':  optional
    host           => 'Str':  default is '127.0.0.1'
    port           => 'Int':  default is 24224
    timeout        => 'Num':  default is 3.0
    socket         => 'Str':  default undef (e.g. "/var/run/fluent/fluent.sock")
    prefer_integer => 'Bool': default 1 (set to Data::MessagePack->prefer_integer)

=item B<post>($tag:Str, $msg:HashRef)

Send message to fluent server with tag.

Return bytes length of written messages.

=item B<post_with_time>($tag:Str, $msg:HashRef, $time:Int)

Send message to fluent server with tag and time.

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
