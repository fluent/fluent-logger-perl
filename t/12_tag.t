use strict;
use warnings;
use Test::More;
use Test::TCP ();
use IO::Socket::INET;

use_ok "Fluent::Logger";

my $port = Test::TCP::empty_port;
my $server = IO::Socket::INET->new(
    LocalPort => $port,
    LocalAddr => "127.0.0.1",
    Listen    => 5,
    ReuseAddr => 1,
) or die "Cannot open server socket: $!";

# A tag must be packed as a msgpack str even if it looks like a number.
# fluentd (>= 1.19) drops events whose tag is not a String.
for my $prefer_integer ( 0, 1 ) {
    for my $tag ( "123", 123 ) {
        my $logger = Fluent::Logger->new(
            host           => "127.0.0.1",
            port           => $port,
            prefer_integer => $prefer_integer,
        );
        ok $logger->post( $tag => { foo => "bar" } ), "post";
        $logger->close;

        my $cs = $server->accept;
        my $data = do { local $/; <$cs> };
        like $data => qr/\A\x93\xa3123/,
            "tag is packed as str (prefer_integer=$prefer_integer)";
    }
}

# A tag must not be packed as a bin even if utf8 is off.
{
    my $logger = Fluent::Logger->new(
        host => "127.0.0.1",
        port => $port,
        utf8 => 0,
    );
    ok $logger->post( "test.tag" => { foo => "bar" } ), "post";
    $logger->close;

    my $cs = $server->accept;
    my $data = do { local $/; <$cs> };
    like $data => qr/\A\x93\xa8test\.tag/, "tag is packed as str (utf8=0)";
}

done_testing;
