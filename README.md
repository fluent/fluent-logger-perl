# NAME

Fluent::Logger - A structured event logger for Fluent

# SYNOPSIS

    use Fluent::Logger;
    

    my $logger = Fluent::Logger->new(
        host => '127.0.0.1',
        port => 24224,
    );
    $logger->post("myapp.access", { "agent" => "foo" });
    # output: myapp.access {"agent":"foo"}
    

    my $logger = Fluent::Logger->new(
        tag_prefix => 'myapp',
        host       => '127.0.0.1',
        port       => 24224,
    );
    $logger->post("access", { "agent" => "foo" });
    # output: myapp.access {"agent":"foo"}

# DESCRIPTION

Fluent::Logger is a structured event logger for Fluent.

# METHODS

- __new__(%args)

create new logger instance.

%args:

    tag_prefix     => 'Str':  optional
    host           => 'Str':  default is '127.0.0.1'
    port           => 'Int':  default is 24224
    timeout        => 'Num':  default is 3.0
    socket         => 'Str':  default undef (e.g. "/var/run/fluent/fluent.sock")
    prefer_integer => 'Bool': default 1 (set to Data::MessagePack->prefer_integer)

- __post__($tag:Str, $msg:HashRef)

Send message to fluent server with tag.

Return bytes length of written messages.

- __post_with_time__($tag:Str, $msg:HashRef, $time:Int)

Send message to fluent server with tag and time.

- __close__()

close connection.

If the logger has pending data, flushing it to server on close.

- __errstr__

return error message.

    $logger->post( info => { "msg": "test" } )
        or die $logger->errstr;

# AUTHOR

HIROSE Masaaki <hirose31 _at_ gmail.com>

Shinichiro Sei <sei _at_ kayac.com>

FUJIWARA Shunichiro <fujiwara _at_ cpan.org>

# THANKS TO

Kazuki Ohta

FURUHASHI Sadayuki

# REPOSITORY

[https://github.com/fluent/fluent-logger-perl](https://github.com/fluent/fluent-logger-perl)

    git clone git://github.com/fluent/fluent-logger-perl.git

patches and collaborators are welcome.

# SEE ALSO

[http://fluent.github.com/](http://fluent.github.com/)

# COPYRIGHT & LICENSE

Copyright FUJIWARA Shunichiro

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.