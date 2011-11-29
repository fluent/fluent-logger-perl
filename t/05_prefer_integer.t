use strict;
use warnings;
use Test::More;
use Test::TCP;
use Time::Piece;
use t::Util qw/ run_fluentd /;
use POSIX qw/ setlocale LC_ALL /;

setlocale(LC_ALL, "C");

my ($server, $dir) = run_fluentd();
my $port = $server->port;

use_ok "Fluent::Logger";


subtest as_int => sub {
    my $logger = Fluent::Logger->new(
        port           => $port,
        prefer_integer => 1,
    );
    my $tag = "test.integer";
    ok $logger->post( $tag, { "as_int" => "123" });
    my $log = `cat $dir/tcp.log*`;
    like $log => qr{"as_int":123};
};

subtest as_str => sub {
    my $logger = Fluent::Logger->new(
        port           => $port,
        prefer_integer => 0,
    );
    my $tag = "test.integer";
    ok $logger->post( $tag, { "as_str" => "123" });
    my $log = `cat $dir/tcp.log*`;
    like $log => qr{"as_str":"123"};
};

subtest change_flag => sub {
    my $logger = Fluent::Logger->new(
        port           => $port,
        prefer_integer => 1,
    );
    my $tag = "test.integer";
    ok $logger->post( $tag, { "change_as_int" => "123" });
    my $log = `cat $dir/tcp.log*`;
    like $log => qr{"change_as_int":123};

    $logger->prefer_integer(0);
    ok $logger->post( $tag, { "change_as_str" => "123" });
    $log = `cat $dir/tcp.log*`;
    like $log => qr{"change_as_str":"123"};
    note $log;
};

done_testing;
