use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Test::More;
use Test::TCP;
use Time::Piece;
use t::Util qw/ run_fluentd slurp_log /;
use POSIX qw/ setlocale LC_ALL /;
use Capture::Tiny qw/ capture /;

use Config;
if ( $Config{d_setlocale} ) {
    setlocale(LC_ALL, "C");
}

my ($server, $dir) = run_fluentd(undef, "udp");
my $port = $server->port;

use_ok "Fluent::Logger::UDP";

subtest udp => sub {
    my $logger = Fluent::Logger::UDP->new( port => $port );

    isa_ok $logger, "Fluent::Logger::UDP";
    ok $logger->post('{"foo":"bar"}'), "post ok";

    sleep 1;
    my $log = slurp_log $dir;
    note $log;
    like $log => qr/"foo":"bar","tag":"test\.udp"/, "match post log";
};

done_testing;
