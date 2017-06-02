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
    my $logger = Fluent::Logger->new( port => $port );

    isa_ok $logger, "Fluent::Logger";
    my $tag = "test.tcp";
    ok $logger->post( $tag, { "foo" => decode_utf8("内部文字列") }), "post str ok";
    ok $logger->post( $tag, { "bar" => "バイナリ列" }), "post bin ok";
    sleep 1;
    my $log = slurp_log $dir;
    note $log;
    like $log => qr/"foo":"内部文字列","tag":"$tag"/, "match post str log";
    like $log => qr/"bar":"バイナリ列","tag":"$tag"/, "match post bin log";
};

done_testing;
