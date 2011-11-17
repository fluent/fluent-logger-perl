use strict;
use Test::More;

require Fluent::Logger;
note("new");
my $obj = new_ok("Fluent::Logger");

# diag explain $obj

done_testing;
