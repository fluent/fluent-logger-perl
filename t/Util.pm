package t::Util;
use strict;
use warnings;
use File::Temp qw/ tempdir /;
use Path::Class qw/ dir /;
use Test::TCP;
use version;

use Exporter 'import';
our $ENABLE_TEST_EVENT_TIME;
our @EXPORT_OK = qw/ streaming_decode_mp run_fluentd slurp_log $ENABLE_TEST_EVENT_TIME /;

sub streaming_decode_mp {
    my $sock   = shift;
    my $offset = 0;
    my $up     = Data::MessagePack::Unpacker->new;
    while( read($sock, my $buf, 1024) ) {
        $offset = $up->execute($buf, $offset);
        if ($up->is_finished) {
            return $up->data;
        }
    }
}

sub slurp_log($) {
    my $dir = shift;
    my @file = grep { !/\.meta$/ } grep { /test\.log/ } dir($dir)->children;
    return join("", map { $_->slurp } @file);
}

sub run_fluentd {
    my $fixed_port = shift;
    my $input = shift || "forward";
    my ($v) = ( `fluentd --version` =~ /^fluentd ([0-9.]+)/ );
    if (!$v) {
        Test::More::plan skip_all => "fluentd is not installed.";
    }
    if (version->parse($v) >= version->parse("0.14.0")) {
        Test::More::note "fluentd version $v: enabling tests for event time.";
        $ENABLE_TEST_EVENT_TIME = 1;
    } else {
        Test::More::note "fluentd version < 0.14.0: disabling tests for event time.";
    }
    my $dir = tempdir( CLEANUP => 1 );
    my $code = sub {
        my $port = shift;
        open my $conf, ">", "$dir/fluent.conf" or die $!;
        if ( $input eq "forward" ) {
            print $conf <<"_END_";
<source>
  type forward
  port ${port}
</source>
_END_
        } elsif ($input eq "tcp" || $input eq "udp") {
            print $conf <<"_END_";
<source>
  type tcp
  tag test.tcp
  port ${port}
  format json
</source>
<source>
  type udp
  tag test.udp
  port ${port}
  format json
</source>
_END_
        }
        print $conf <<"_END_";
<match test.*>
  type file
  path ${dir}/test.log
  time_format %Y-%m-%dT%H:%M:%S.%N%z
</match>
_END_
        exec "fluentd", "-c", "$dir/fluent.conf";
        die $!;
    };
    my $server = Test::TCP->new(
        code            => $code,
        wait_port_sleep => 0.1,
        wait_port_retry => 100,
        $fixed_port ? ( port => $fixed_port ) : (),
    );
    return ($server, $dir);
}

1;
