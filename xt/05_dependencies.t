# -*- mode: cperl; -*-
use Test::Dependencies
    exclude => [qw(Test::Dependencies Test::Base Test::Perl::Critic
                   Fluent::Logger)],
    style   => 'light';
ok_dependencies();
