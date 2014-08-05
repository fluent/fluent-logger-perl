use strict;
use warnings;
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

my $logger = Fluent::Logger->new( port => $port );
my $local_port = $logger->socket_io->sockport;

ok $local_port, "local port: $local_port";
ok $logger->post("test.parent" => { foo => "bar" });

my $pid = fork();
if ($pid == 0) {
    # child
    note "child pid: $$";
    ok $logger->post("test.child" => { foo => "bar" });
    ok $logger->socket_io->sockport != $local_port, "different port on child";
    exit;
}
elsif ($pid) {
    # parent
    note "parent pid: $$";
    ok $logger->post("test.parent" => { foo => "bar" });
    is $logger->socket_io->sockport => $local_port, "same port on parent";
    waitpid($pid, 0);
}
else {
    die $!;
}

done_testing;
