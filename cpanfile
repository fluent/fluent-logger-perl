requires 'Data::MessagePack', '0.35_01';
requires 'Mouse';
requires 'Time::Piece';

on build => sub {
    requires 'Capture::Tiny';
    requires 'ExtUtils::MakeMaker', '6.36';
    requires 'Path::Class';
    requires 'Test::More', '0.88';
    requires 'Test::SharedFork';
    requires 'Test::TCP', '1.3';
};

on test => sub {
    requires 'Number::Format';
};
