use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Test::More;
use Test::TCP;
use Time::HiRes qw/ time /;
use t::Util qw/ run_fluentd /;

Test::More::plan skip_all => "skip < 5.10" if $] < 5.010;

my ($server, $dir) = run_fluentd();
my $port = $server->port;

require Number::Format;

use_ok "Fluent::Logger";
diag "starting benchmark...";
for my $size ( 10, 100, 1000 ) {
    my $n = 50000;
    my $msg = "x" x $size;
    my $start  = time;
    my $logger = Fluent::Logger->new( port => $port, ack => 1 );
    my $w = 0;
    for ( 1 .. $n ) {
        $w += $logger->post( "test.benchmark", { "msg" => $msg } );
    }
    my $elapsed = time - $start;
    diag sprintf "%.2f sec / %d msgs (%d bytes) = %.2fqps (%sbps)",
             $elapsed, $n, $w / $n, $n / $elapsed,
             Number::Format::format_bytes($w * 8 / $elapsed);
}

done_testing;
