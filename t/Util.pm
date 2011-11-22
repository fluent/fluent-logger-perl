package t::Util;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/ streaming_decode_mp /;

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

1;
