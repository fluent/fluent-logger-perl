requires 'Data::MessagePack', '0.35_01';
requires 'Class::Tiny';
requires 'Time::Piece';
requires 'Data::MessagePack::Stream';
requires 'Data::UUID';

on build => sub {
    requires 'Capture::Tiny';
    requires 'ExtUtils::MakeMaker', '6.36';
    requires 'Path::Class';
    requires 'Test::More', '0.88';
    requires 'Test::SharedFork';
    requires 'Test::TCP', '1.3';
    requires 'version', '0.77';
};

on develop => sub {
    requires 'Number::Format';
};
