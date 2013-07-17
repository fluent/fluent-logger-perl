use strict;
use warnings;
use Test::More;
use Test::TCP;
use Time::HiRes qw/ time /;
use t::Util qw/ run_fluentd /;

require Number::Format;

sub dummy_server {
    Test::TCP->new(
        code => sub {
            my $port = shift;
            open STDOUT, ">", "/dev/null";
            exec "nc", "-k", "-l", $port;
        },
        wait_port_sleep => 0.1,
        wait_port_retry => 100,
    );
}

use_ok "Fluent::Logger";
diag "starting benchmark...";
for my $size ( 10, 100, 1000 ) {
    my $server = dummy_server;
    my $n = 100_000;
    my $msg = "x" x $size;
    my $start  = time;
    my $logger = Fluent::Logger->new(
        port => $server->port,
    );
    my $w = 0;
    for ( 1 .. $n ) {
        $w += $logger->post( "test.benchmark", { "msg" => $msg } );
    }
    my $elapsed = time - $start;
    diag sprintf "%.2f sec / %d msgs (%d bytes) = %.2fqps (%sbps)",
             $elapsed, $n, $w / $n, $n / $elapsed,
             Number::Format::format_bytes($w * 8 / $elapsed);
    undef $server;
    sleep 1;
}

done_testing;
