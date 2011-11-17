# -*- coding: utf-8; -*-
package Fluent::Logger;

use strict;
use warnings;

our $VERSION = '0.01_01';

use Smart::Args;
use IO::Socket::INET;
use Data::MessagePack;

sub new {
    args(my $class,
         my $tag_prefix   => { isa => 'Str', optional => 1 },
         my $host         => { isa => 'Str', default => '127.0.0.1' },
         my $port         => { isa => 'Int', default => 24224 } ,
         my $timeout      => { isa => 'Num', default => 3.0 },
         my $buffer_limit => { isa => 'Int', default => 8*1024*1024 }, # fixme
        );

    my $self = bless {
        tag_prefix   => $tag_prefix,
        host         => $host,
        port         => $port,
        timeout      => $timeout,
        buffer_limit => $buffer_limit,
        socket       => undef,
        packer       => Data::MessagePack->new,
       }, $class;

    $self->_connect;

    return $self;
}

sub _connect {
    args(my $self);

    return if $self->{socket};

    $self->{socket} = IO::Socket::INET->new(
        PeerAddr  => $self->{host},
        PeerPort  => $self->{port},
        Proto     => 'tcp',
        Timeout   => $self->{timeout},
        ReuseAddr => 1,
       ) or die $!;

    return 1;
}

sub close {
    args(my $self);

    $self->{socket}->close if $self->{socket};
}

sub post {
    my($self, $tag, $msg) = @_;
    $self->_post(tag => $tag||"", msg => $msg);
}

sub _post {
    args(my $self,
         my $tag => { isa => 'Str', default => "" },
         my $msg => { isa => 'HashRef' },
    );

    $tag = join('.', $self->{tag_prefix}, $tag) if $self->{tag_prefix};
    my $data = $self->_make_data(
        tag  => $tag,
        time => time(),
        msg  => $msg,
       );

    $self->_send(data => $data);
}

sub _make_data {
    args(my $self,
         my $tag  => 'Str',
         my $time => 'Int',
         my $msg  => 'HashRef',
    );

    return $self->{packer}->pack([$tag, $time, $msg]);
}

sub _send {
    args(my $self,
         my $data => 'Value',
    );

    $self->{socket}->send($data);
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

=item B<post>($tag:Str, $msg:HashRef)

send message to fluent server with tag.


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

