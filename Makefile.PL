use inc::Module::Install;
#use Module::Install::AuthorTests;
#use Module::Install::Repository;

name     'Fluent-Logger';
all_from 'lib/Fluent/Logger.pm';
license  'perl';
auto_set_repository;
repository 'https://github.com/hirose31/fluent-logger-perl';

requires 'Data::MessagePack';
requires 'Mouse';
requires 'Time::Piece';

test_requires 'Test::More' => 0.88;
test_requires 'Test::TCP'  => 1.13;
test_requires 'Test::SharedFork';

tests_recursive;
author_tests 'xt';

WriteAll;
