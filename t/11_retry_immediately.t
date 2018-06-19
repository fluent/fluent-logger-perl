use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Test::More;
use t::Util qw/ run_fluentd /;
use POSIX qw/ setlocale LC_ALL /;
use Test::SharedFork;

use Config;
if ( $Config{d_setlocale} ) {
    setlocale(LC_ALL, "C");
}

my ($server, $dir) = run_fluentd();
my $port = $server->port;

use_ok "Fluent::Logger";

my $logger = Fluent::Logger->new(
   port              => $port,
   retry_immediately => 1,
);

ok $logger->post( "test.error" => { foo => "ok" } );

undef $server; # shutdown
sleep 1;

($server, $dir) = run_fluentd($port); # start fluentd on the same port

ok $logger->post( "test.error" => { foo => "retried?" } );

done_testing;
