use strict;
use warnings;
use Test::More;

require Fluent::Logger;
use Test::TCP;

subtest 'new' => sub {
    test_tcp(
        client => sub {
            my $port = shift;

            my $obj = Fluent::Logger->new({
                port => $port,
            });
            ok $obj;
        },
        server => sub {
            my $port = shift;

            my $sock = IO::Socket::INET->new(
                LocalPort => $port,
                LocalAddr => '127.0.0.1',
                Proto     => 'tcp',
                Listen    => 5,
            ) or die "Cannot open server socket: $!";

            $sock->listen or die $!;
            while (my $c = $sock->accept) {
                print $c;
            }
        },
    );
};

done_testing;
