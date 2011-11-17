# NAME

Fluent::Logger - A structured event logger for Fluent

# SYNOPSIS

    use Fluent::Logger;
    

    my $logger = Fluent::Logger->new(host => '127.0.0.1', port => 24224);
    $logger->post("myapp.access", { "agent" => "foo" });
    # output: myapp.access {"agent":"foo"}
    

    my $logger = Fluent::Logger->new(tag_prefix => 'myapp', host => '127.0.0.1', port => 24224);
    $logger->post("access", { "agent" => "foo" });
    # output: myapp.access {"agent":"foo"}

# WARNING

__This software is under the heavy development and considered ALPHA
quality till the version hits v1.0.0. Things might be broken, not all
features have been implemented, and APIs will be likely to change. YOU
HAVE BEEN WARNED.__

## TODO

- * buffering and pending

- * timeout, reconnect

- * write pod

- * test cases

# DESCRIPTION

Fluent::Logger is a structured event logger for Fluent.

# METHODS

- __new__(%args)

create new logger instance.

%args:

    tag_prefix  => 'Str': optional
    host        => 'Str': default is '127.0.0.1'
    port        => 'Int': default is 24224
    timeout     => 'Num': default is 3.0

- __post__($tag:Str, $msg:HashRef)

send message to fluent server with tag.



# AUTHOR

HIROSE Masaaki <hirose31 _at_ gmail.com>

# REPOSITORY

<https://github.com/hirose31/fluent-logger-perl>

    git clone git://github.com/hirose31/fluent-logger-perl.git

patches and collaborators are welcome.

# SEE ALSO

<http://fluent.github.com/>

# COPYRIGHT & LICENSE

Copyright HIROSE Masaaki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.