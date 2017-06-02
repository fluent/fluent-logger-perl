use strict;
use FindBin;
use lib "$FindBin::Bin/../";
use Test::More;
use Test::SharedFork;
use File::Temp qw/ tempdir /;
use t::Util qw/ streaming_decode_mp /;
use Test::TCP();
use IO::Socket::INET;

use_ok "Fluent::Logger";

my $port = Test::TCP::empty_port;
note "port: $port";

my $pid = fork();
if ($pid == 0) {
    Test::SharedFork->child;
    sleep 1;
    my $logger = Fluent::Logger->new(
        host => "127.0.0.1",
        port => $port,
    );
    isa_ok $logger, "Fluent::Logger";
    ok $logger->post("test.debug" => { foo => "bar" });
    ok $logger->close;
}
elsif (defined $pid) {
    Test::SharedFork->parent;
    my $sock = IO::Socket::INET->new(
        LocalPort => $port,
        LocalAddr => "127.0.0.1",
        Listen    => 5,
    ) or die "Cannot open server socket: $!";

    while (my $cs = $sock->accept) {
        my $data = streaming_decode_mp($cs);
        note explain $data;
        isa_ok $data         => "ARRAY";
        is $data->[0]        => "test.debug";
        is_deeply $data->[2] => { foo => "bar" };
        last;
    }
    sleep 1;
    done_testing;
};
