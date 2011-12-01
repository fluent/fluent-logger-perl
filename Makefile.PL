use inc::Module::Install;
#use Module::Install::AuthorTests;
#use Module::Install::Repository;

name     'Fluent-Logger';
all_from 'lib/Fluent/Logger.pm';
license  'perl';
auto_set_repository;
repository 'https://github.com/fluent/fluent-logger-perl';

requires 'Data::MessagePack' => '0.35_01';
requires 'Mouse';
requires 'Time::Piece';
requires 'JSON';

test_requires 'Test::More' => 0.88;
test_requires 'Test::TCP'  => 1.13;
test_requires 'Test::SharedFork';
test_requires 'Path::Class';
test_requires 'Capture::Tiny';

tests_recursive;
author_tests 'xt';

WriteAll;
