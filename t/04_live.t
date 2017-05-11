use strict;
use warnings;
use Test::More;
use Test::TCP;
use Time::Piece;
use t::Util qw/ run_fluentd slurp_log $ENABLE_TEST_EVENT_TIME /;
use POSIX qw/ setlocale LC_ALL /;
use Capture::Tiny qw/ capture /;

use Config;
if ( $Config{d_setlocale} ) {
    setlocale(LC_ALL, "C");
}

my ($server, $dir) = run_fluentd();
my $port = $server->port;

use_ok "Fluent::Logger";

subtest tcp => sub {
    my $logger = Fluent::Logger->new( port => $port );

    isa_ok $logger, "Fluent::Logger";
    my $tag = "test.tcp";
    ok $logger->post( $tag, { "foo" => "bar" }), "post ok";

    my $time     = time - int rand(3600);
    my $time_str = localtime($time)->strftime("%Y-%m-%dT%H:%M:%S.000000000%z");

    ok $logger->post_with_time( $tag, { "FOO" => "BAR" }, $time ), "post_with_time ok";
    sleep 1;
    my $log = slurp_log $dir;
    note $log;
    like $log => qr/"foo":"bar","tag":"$tag"/, "match post log";
    like $log => qr/"FOO":"BAR","tag":"$tag","time":"\Q$time_str\E"/, "match post_with_time log";
};

subtest tcp_event_time => sub {
    plan skip_all => "installed fluentd not supports event_time"
        unless $ENABLE_TEST_EVENT_TIME;

    my $logger = Fluent::Logger->new( port => $port, event_time => 1 );
    isa_ok $logger, "Fluent::Logger";
    my $tag = "test.tcp";
    ok $logger->post( $tag, { "event_time" => "foo" }), "post ok";

    my $time     = Time::HiRes::time;
    my $time_i   = int($time);
    my $nanosec  = sprintf("%09d", int(($time - $time_i) * 10 ** 9));
    my $time_str = localtime($time)->strftime("%Y-%m-%dT%H:%M:%S.${nanosec}%z");

    ok $logger->post_with_time( $tag, { "event_time" => "bar" }, $time ), "post_with_time ok";
    sleep 1;
    my $log = slurp_log $dir;
    note $log;
    like $log => qr/"event_time":"foo","tag":"$tag","time":"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{9}[+-]\d{4}"/, "match post log";
    like $log => qr/"event_time":"bar","tag":"$tag","time":"\Q$time_str\E"/, "match post_with_time log";
};

subtest ack => sub {
    my $logger = Fluent::Logger->new( port => $port, ack => 1 );

    isa_ok $logger, "Fluent::Logger";
    my $tag = "test.tcp";
    ok $logger->post( $tag, { "foo" => "bar" }), "post ok";

    my $time     = time - int rand(3600);
    my $time_str = localtime($time)->strftime("%Y-%m-%dT%H:%M:%S.000000000%z");

    ok $logger->post_with_time( $tag, { "FOO" => "BAR" }, $time ), "post_with_time ok";
    sleep 1;
    my $log = slurp_log $dir;
    note $log;
    like $log => qr/"foo":"bar","tag":"$tag"/, "match post log";
    like $log => qr/"FOO":"BAR","tag":"$tag","time":"\Q$time_str\E"/, "match post_with_time log";
};

subtest error => sub {
    my $logger = Fluent::Logger->new( port => $port );
    ok $logger->post( "test.error" => { foo => "ok" } );

    undef $server; # shutdown

    my $r;
    $r = $logger->post( "test.error" => "not hashref?" );
    is $r => undef, "not hash ref";
    like $logger->errstr => qr/HashRef/i;

    $r = $logger->post( "test.error" => { "foo" => "broken pipe?" } );
    is $r => undef, "broken pipe";
    like $logger->errstr => qr/Broken pipe/i;

    $r = $logger->post( "test.error" => { "foo" => "connection refused?" } );
    is $r => undef, "connection refused";
    like $logger->errstr => qr/Can't connect: (?:Connection refused|Invalid argument)/i;

    sleep 1;

    # restart server on the same port
    ($server, $dir) = run_fluentd($port);
    ok $logger->post( "test.error" => { foo => "reconnected?" } ), "reconnected";

    undef $server;
    sleep 1;
    ($server, $dir) = run_fluentd($port);

    ok !$logger->post( "test.error" => { foo => "retried?" } );
    my ($stdout, $stderr) = capture {
        undef $logger;
    };
    like $stderr, qr{flushed success}i, "flushed success logged";
    note $stderr;

    kill USR1 => $server->pid;
    undef $server;

    my $log = slurp_log $dir;
    like $log => qr{"foo":"retried\?"}, "retried sent";
};

subtest lost => sub {
    my $logger = Fluent::Logger->new( port => $port );
    ok !$logger->post( "test.lost" => { foo => "to be lost first" } );
    ok !$logger->post( "test.lost" => { foo => "to be lost second" } );

    my ($stdout, $stderr) = capture {
        undef $logger;
    };
    like $stderr, qr{LOST}i, "lost logged";
    note $stderr;
};

done_testing;
