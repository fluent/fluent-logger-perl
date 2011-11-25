package t::Util;
use strict;
use warnings;
use File::Temp qw/ tempdir /;

use Exporter 'import';
our @EXPORT_OK = qw/ streaming_decode_mp run_fluentd /;

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

sub run_fluentd {
    my $fixed_port = shift;
    if ( system("fluentd", "--version") != 0 ) {
        Test::More::plan skip_all => "fluentd is not installed.";
    }

    my $dir = tempdir( CLEANUP => 1 );
    my $code = sub {
        my $port = shift;
        open my $conf, ">", "$dir/fluent.conf" or die $!;
        print $conf <<"_END_";
<source>
  type forward
  port ${port}
</source>
<match test.*>
  type file
  path ${dir}/tcp.log
</match>
_END_
        exec "fluentd", "-c", "$dir/fluent.conf";
        die $!;
    };
    my $server = Test::TCP->new(
        code => $code,
        $fixed_port ? ( port => $fixed_port ) : (),
    );
    return ($server, $dir);
}

1;
