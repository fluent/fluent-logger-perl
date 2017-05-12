use strict;
use Test::More;
use ExtUtils::MakeMaker ();

BEGIN { use_ok 'Fluent::Logger' or BAIL_OUT('will not work with compilation problems'); }

done_testing;
