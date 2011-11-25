# -*- mode: cperl; -*-
use Test::More;
eval {
    require Test::Dependencies;
    import  Test::Dependencies 
        exclude => [qw(Test::Dependencies Test::Base Test::Perl::Critic
                       Fluent::Logger t::Util )],
        style   => 'light';
};
plan skip_all => "Test::Dependencies required for testing dependencies"
    if $@;

ok_dependencies();
