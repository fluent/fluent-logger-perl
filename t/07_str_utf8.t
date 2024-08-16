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

use Config;
if ( $Config{d_setlocale} ) {
    setlocale(LC_ALL, "C");
}

my ($server, $dir) = run_fluentd();
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
    note $log;
    like $log => qr/"foo":"内部文字列","tag":"$tag"/, "match post str log";
    like $log => qr/"bar":"バイナリ列","tag":"$tag"/, "match post bin log";
    like $log => qr/"broken":"\xE0\x80\xAF","tag":"$tag"/, "match post broken utf8 log";
};

done_testing;
