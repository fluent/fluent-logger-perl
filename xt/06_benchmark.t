use strict;
use warnings;
use Test::More;
use Test::TCP;
use Number::Format qw/ format_bytes /;
use Time::HiRes qw/ time /;
use t::Util qw/ run_fluentd /;

my ($server, $dir) = run_fluentd();
my $port = $server->port;

use_ok "Fluent::Logger";
diag "starting benchmark...";
for my $size ( 10, 100, 1000 ) {
    my $n = 100000;
    my $msg = "x" x $size;
    my $start  = time;
    my $logger = Fluent::Logger->new( port => $port );
    my $w;
    for ( 1 .. $n ) {
        $w = $logger->post( "test.benchmark", { "msg" => $msg } );
    }
    my $elapsed = time - $start;
    diag sprintf "%.2f sec / %d msgs (%d bytes) = %.2fqps (%sbps)",
             $elapsed, $n, $w, $n / $elapsed, format_bytes($w * 8 * $n / $elapsed);
}

done_testing;
