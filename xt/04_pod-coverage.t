use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage"
    if $@;
all_pod_coverage_ok(
    { also_private => [ qr/^[A-Z_]+$/,
                        # attributes
                        qw/ tag_prefix host port socket timeout buffer_limit
                            max_write_retry write_length socket_io
                            errors prefer_integer packer pending
                            connect_error_history owner_pid
                          / ], },
);
