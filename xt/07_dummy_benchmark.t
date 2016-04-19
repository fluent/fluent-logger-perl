use strict;
use warnings;
use Test::More;
use Test::TCP;
use Time::HiRes qw/ time sleep /;
use t::Util qw/ run_fluentd /;
use File::Temp qw/ tempdir /;

Test::More::plan skip_all => "skip < 5.10" if $] < 5.010;

require Proc::Guard;
require Number::Format;

use_ok "Fluent::Logger";
diag "starting benchmark...";

for my $type ( "tcp", "unix" ) {
    for my $size ( 10, 100, 1000 ) {
        my ($server, $dir) = dummy_server($type);
        my $n = 100_000;
        my $msg = "x" x $size;
        my @args = $type eq "tcp"
                 ? ( port   => $server->port )
                 : ( socket => "$dir/server.sock" );
        my $start  = time;
        my $logger = Fluent::Logger->new(@args);
        my $w = 0;
        for ( 1 .. $n ) {
            $w += $logger->post( "test.benchmark", { "msg" => $msg } );
        }
        my $elapsed = time - $start;
        diag sprintf "%s: %.2f sec / %d msgs (%d bytes) = %.2fqps (%sbps)",
                $type, $elapsed, $n, $w / $n, $n / $elapsed,
                Number::Format::format_bytes($w * 8 / $elapsed);
     }
}

done_testing;

sub dummy_server {
    my ($type) = @_;
    my $dir = tempdir( CLEANUP => 1 );
    my @nc = qw/ nc -k -l /;
    my $server;
    if ($type eq "tcp") {
        $server = Test::TCP->new(
            code => sub {
                my $port = shift;
                open STDOUT, ">", "/dev/null";
                exec @nc, $port;
            },
        );
    }
    else {
        my $socket = "$dir/server.sock";
        $server = Proc::Guard->new(
            code => sub {
                open STDOUT, ">", "/dev/null";
                exec @nc, "-U", $socket;
            },
        );
        sleep 0.1 while !-e $socket; # wait for socket created
    }
    ($server, $dir);
}

