[![Build Status](https://github.com/fluent/fluent-logger-perl/actions/workflows/test.yaml/badge.svg)](https://github.com/fluent/fluent-logger-perl/actions/workflows/test.yaml)

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

Fluent::Logger is a structured event logger for Fluentd.

# METHODS

- **new**(%args)

    create new logger instance.

    %args:

        tag_prefix                  => 'Str':  optional
        host                        => 'Str':  default is '127.0.0.1'
        port                        => 'Int':  default is 24224
        timeout                     => 'Num':  default is 3.0
        socket                      => 'Str':  default undef (e.g. "/var/run/fluent/fluent.sock")
        prefer_integer              => 'Bool': default 1 (set to Data::MessagePack->prefer_integer)
        utf8                        => 'Bool': default 1 (set to Data::MessagePack->utf8)
        event_time                  => 'Bool': default 0 (timestamp includes nanoseconds, supported by fluentd >= 0.14.0)
        buffer_limit                => 'Int':  defualt 8388608 (8MB)
        buffer_overflow_handler     => 'Code': optional
        truncate_buffer_at_overflow => 'Bool': default 0
        ack                         => 'Bool': default 0 (not works on MSWin32)
        retry_immediately           => 'Int':  default 0 (retries immediately  N times on error occured)

    - buffer\_overflow\_handler

        You can inject your own custom coderef to handle buffer overflow in the event of connection failure.
        This will mitigate the loss of data instead of simply throwing data away.

        Your proc should accept a single argument, which will be the internal buffer of messages from the logger.
        This coderef is also called when logger.close() failed to flush the remaining internal buffer of messages.
        A typical use-case for this would be writing to disk or possibly writing to Redis.

    - truncate\_buffer\_at\_overflow

        When truncate\_buffer\_at\_overflow is true and pending buffer size is larger than buffer\_limit, post() returns undef.

        Pending buffer still be kept, but last message passed to post() is not sent and not appended to buffer. You may handle the message by other method.

    - ack

        post() waits ack response from server for each messages.

        An exception will raise if ack is miss match or timed out.

        This option does not work on MSWin32 platform currently, because Data::MessagePack::Stream does not work.

    - retry\_immediately

        By default, Fluent::Logger will retry to send the buffer at next post() called when an error occured in post().

        If retry\_immediately(N) is set, retries immediately max N times.

- **post**($tag:Str, $msg:HashRef)

    Send message to fluent server with tag.

    Return bytes length of written messages.

    If event\_time is set to true, log's timestamp includes nanoseconds.

- **post\_with\_time**($tag:Str, $msg:HashRef, $time:Int|Float)

    Send message to fluent server with tag and time.

    If event\_time is set to true, $time argument accepts Float value (such as Time::HiRes::time()).

- **close**()

    close connection.

    If the logger has pending data, flushing it to server on close.

- **errstr**

    return error message.

        $logger->post( info => { "msg": "test" } )
            or die $logger->errstr;

# AUTHOR

HIROSE Masaaki &lt;hirose31 \_at\_ gmail.com>

Shinichiro Sei &lt;sei \_at\_ kayac.com>

FUJIWARA Shunichiro &lt;fujiwara \_at\_ cpan.org>

# THANKS TO

Kazuki Ohta

FURUHASHI Sadayuki

lestrrat

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
