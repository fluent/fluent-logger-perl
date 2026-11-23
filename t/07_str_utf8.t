use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Test::More;
use Test::TCP;
use Time::Piece;
use Encode;
use t::Util qw/ run_fluentd slurp_log /;
use POSIX qw/ setlocale LC_ALL /;
use Capture::Tiny qw/ capture /;

# The JSON formatter of fluentd >= 1.20.1 rejects binary and malformed UTF-8
# strings, so the output is formatted as msgpack to check raw bytes.
sub value_re {
    my ($key, $value, $tag) = @_;
    my $klen = chr(0xa0 + length $key);
    my $tlen = chr(0xa0 + length $tag);
    # key and value are fixstr (utf8 => 1) or bin8 (utf8 => 0)
    qr/(?:\Q$klen\E|\xc4.)\Q$key\E(?:[\xa0-\xbf]|\xc4.)\Q$value\E\xa3tag\Q$tlen$tag\E/s;
}

use Config;
if ( $Config{d_setlocale} ) {
    setlocale(LC_ALL, "C");
}

my ($server, $dir) = run_fluentd(undef, "forward", "msgpack");
my $port = $server->port;

use_ok "Fluent::Logger";

subtest str_bin => sub {
    my $logger = Fluent::Logger->new( port => $port, utf8 => 1 );

    isa_ok $logger, "Fluent::Logger";
    is $logger->packer->get_utf8, 1, "packer utf8 is on";
    my $tag = "test.tcp";
    ok $logger->post( $tag, { "foo" => decode_utf8("内部文字列") }), "post str ok";
    ok $logger->post( $tag, { "bar" => "バイナリ列" }), "post bin ok";
    ok $logger->post( $tag, { "broken" => "\xE0\x80\xAF" }), "post broken utf8 ok";
    sleep 1;
    my $log = slurp_log $dir;
    like $log => value_re("foo", "内部文字列", $tag), "match post str log";
    like $log => value_re("bar", "バイナリ列", $tag), "match post bin log";
    like $log => value_re("broken", "\xE0\x80\xAF", $tag), "match post broken utf8 log";
};

done_testing;
