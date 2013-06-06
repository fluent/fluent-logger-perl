use strict;
use warnings;
use Test::More;
use Test::TCP;
use Time::Piece;
use t::Util qw/ run_fluentd slurp_log /;
use POSIX qw/ setlocale LC_ALL /;
use Capture::Tiny qw/ capture /;

setlocale(LC_ALL, "C");

my ($server, $dir) = run_fluentd();
my $port = $server->port;

use_ok "Fluent::Logger";

subtest tcp => sub {
    my $logger = Fluent::Logger->new( port => $port );

    isa_ok $logger, "Fluent::Logger";
    my $tag = "test.tcp";
    ok $logger->post( $tag, { "foo" => "bar" }), "post ok";

    my $time     = time - int rand(3600);
    my $time_str = localtime($time)->strftime("%Y-%m-%dT%H:%M:%S%z");
    $time_str =~ s/(\d\d)$/:$1/; # TZ offset +0000 => +00:00

    ok $logger->post_with_time( $tag, { "FOO" => "BAR" }, $time ), "post_with_time ok";
    sleep 1;
    my $log = slurp_log $dir;
    note $log;
    like $log => qr{$tag\t\{"foo":"bar"\}}, "match post log";
    like $log => qr{\Q$time_str\E\t$tag\t\{"FOO":"BAR"\}}, "match post_with_time log";
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
    like $logger->errstr => qr/Connection refused/i;

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
