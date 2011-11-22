use strict;
use Test::More;
use Test::SharedFork;
use File::Temp qw/ tempdir /;
use t::Util qw/ streaming_decode_mp /;
use IO::Socket::UNIX;

use_ok "Fluent::Logger";

my $dir  = tempdir( CLEANUP => 1 );
my $sock = "$dir/test.sock";
note "socket: $sock";

my $pid = fork();
if ($pid == 0) {
    Test::SharedFork->child;
    sleep 1;
    my $logger = Fluent::Logger->new( socket => $sock );
    isa_ok $logger, "Fluent::Logger";
    ok $logger->post("test.debug" => { foo => "bar" });
    ok $logger->close;
}
elsif (defined $pid) {
    Test::SharedFork->parent;
    my $sock = IO::Socket::UNIX->new(
        Local  => $sock,
        Listen => 5,
    ) or die "Cannot open server socket: $!";

    while (my $cs = $sock->accept) {
        my $data = streaming_decode_mp($cs);
        note explain $data;
        isa_ok $data         => "ARRAY";
        is $data->[0]        => "test.debug";
        is_deeply $data->[2] => { foo => "bar" };
        last;
    }
    done_testing;
};
