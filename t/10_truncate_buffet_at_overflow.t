use strict;
use warnings;
use utf8;
use Test::More;
use Test::TCP;
use Fluent::Logger;

my $port = Test::TCP::empty_port();

my $handler_called;

my $no_such_logger = Fluent::Logger->new(
    host                        => '127.0.0.1',
    port                        => $port,
    buffer_limit                => 8*1024*1024,
    truncate_buffer_at_overflow => 1,
);
for (1..8) {
    ok ! $no_such_logger->post("test", { "k" => "v" x (1024 * 1024) });
}

for (1..8) {
    ok ! $no_such_logger->post("test", { "k" => "v" x (1024 * 1024) });
}
ok length($no_such_logger->pending) <= 8*1024*1024, "pending buffer size > 8*1024*1024";

undef $no_such_logger;

done_testing;

