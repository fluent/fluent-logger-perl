use inc::Module::Install;
#use Module::Install::AuthorTests;
#use Module::Install::Repository;

name     'Fluent-Logger';
all_from 'lib/Fluent/Logger.pm';
license  'perl';
auto_set_repository;
repository 'https://github.com/hirose31/fluent-logger-perl';

requires 'Smart::Args';
requires 'Data::MessagePack';

test_requires 'Test::More' => 0.88;

tests_recursive;
author_tests 'xt';

use_test_base;
WriteAll;

