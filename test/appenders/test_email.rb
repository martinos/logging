# $Id$

require File.join(File.dirname(__FILE__), %w[.. setup])
require 'flexmock'

module TestLogging
module TestAppenders

  class TestEmail < Test::Unit::TestCase
    include FlexMock::TestCase
    include LoggingTestCase

    def setup
      super
      ::Logging.define_levels %w(debug info warn error fatal)
      @levels = ::Logging::LEVELS

      flexmock(Net::SMTP).new_instances do |m|
        m.should_receive(:start).at_least.once.with(
            'test.logging', 'test', 'test', :cram_md5, Proc).and_yield(m)
        m.should_receive(:sendmail).at_least.once.with(String, 'me', ['you'])
      end

      @appender = ::Logging::Appenders::Email.new('email',
          'from' => 'me', 'to' => 'you',
          :buffsize => '3', :immediate_at => 'error, fatal',
          :domain => 'test.logging', :acct => 'test', :passwd => 'test'
      )
    end

    def test_initialize
      assert_raise(ArgumentError, 'Must specify from address') {
        ::Logging::Appenders::Email.new('email')
      }
      assert_raise(ArgumentError, 'Must specify to address') {
        ::Logging::Appenders::Email.new('email', :from => 'me')
      }
      assert_nothing_raised {
        ::Logging::Appenders::Email.new('email', :from => 'me', :to => 'you')
      }

      appender = ::Logging::Appenders::Email.new('email',
          'from' => 'me', 'to' => 'you'
      )

      assert_equal(100, appender.instance_variable_get(:@buffsize))
      assert_equal([], appender.instance_variable_get(:@immediate))
      assert_equal('localhost', appender.server)
      assert_equal(25, appender.port)
      assert_equal(ENV['HOSTNAME'], appender.domain)
      assert_equal(nil, appender.acct)
      assert_equal(:cram_md5, appender.authtype)
      assert_equal("Message of #{$0}", appender.subject)

      appender = ::Logging::Appenders::Email.new('email',
          'from' => 'lbrinn@gmail.com', 'to' => 'everyone',
          :buffsize => '1000', :immediate_at => 'error, fatal',
          :server => 'smtp.google.com', :port => '443',
          :domain => 'google.com', :acct => 'lbrinn',
          :passwd => '1234', :authtype => 'tls',
          :subject => "I'm rich and you're not"
      )

      assert_equal('lbrinn@gmail.com', appender.instance_variable_get(:@from))
      assert_equal(['everyone'], appender.instance_variable_get(:@to))
      assert_equal(1000, appender.instance_variable_get(:@buffsize))
      assert_equal('1234', appender.instance_variable_get(:@passwd))
      assert_equal([nil, nil, nil, true, true],
                   appender.instance_variable_get(:@immediate))
      assert_equal('smtp.google.com', appender.server)
      assert_equal(443, appender.port)
      assert_equal('google.com', appender.domain)
      assert_equal('lbrinn', appender.acct)
      assert_equal(:tls, appender.authtype)
      assert_equal("I'm rich and you're not", appender.subject)
    end

    def test_append
      # with a buffer size of 0, mail will be sent each time a log event
      # occurs
      @appender.instance_variable_set(:@buffsize, 0)
      event = ::Logging::LogEvent.new('TestLogger', @levels['warn'],
                                      [1, 2, 3, 4], false)
      @appender.append event
      assert_not_equal(@levels.length, @appender.level)
      assert_equal(0, @appender.queued_messages)

      # increase the buffer size and log a few events
      @appender.instance_variable_set(:@buffsize, 3)
      @appender.append event
      @appender.append event
      assert_equal(2, @appender.queued_messages)

      @appender.append event
      assert_not_equal(@levels.length, @appender.level)
      assert_equal(0, @appender.queued_messages)

      # error and fatal messages should be send immediately (no buffering)
      error = ::Logging::LogEvent.new('ErrLogger', @levels['error'],
                                      'error message', false)
      fatal = ::Logging::LogEvent.new('FatalLogger', @levels['fatal'],
                                      'fatal message', false)

      @appender.append event
      @appender.append fatal
      assert_not_equal(@levels.length, @appender.level)
      assert_equal(0, @appender.queued_messages)

      @appender.append error
      assert_not_equal(@levels.length, @appender.level)
      assert_equal(0, @appender.queued_messages)

      @appender.append event
      assert_equal(1, @appender.queued_messages)
    end

    def test_concat
      # with a buffer size of 0, mail will be sent each time a log event
      # occurs
      @appender.instance_variable_set(:@buffsize, 0)
      @appender << 'test message'
      assert_not_equal(@levels.length, @appender.level)
      assert_equal(0, @appender.queued_messages)

      # increase the buffer size and log a few events
      @appender.instance_variable_set(:@buffsize, 3)
      @appender << 'another test message'
      @appender << 'a second test message'
      assert_equal(2, @appender.queued_messages)

      @appender << 'a third test message'
      assert_not_equal(@levels.length, @appender.level)
      assert_equal(0, @appender.queued_messages)
    end

    def test_flush
      event = ::Logging::LogEvent.new('TestLogger', @levels['info'],
                                      [1, 2, 3, 4], false)
      @appender.append event
      @appender << 'test message'
      assert_equal(2, @appender.queued_messages)

      @appender.flush
      assert_not_equal(@levels.length, @appender.level)
      assert_equal(0, @appender.queued_messages)
    end

    def test_close
      event = ::Logging::LogEvent.new('TestLogger', @levels['info'],
                                      [1, 2, 3, 4], false)
      @appender.append event
      @appender << 'test message'
      assert_equal(2, @appender.queued_messages)

      @appender.close
      assert_not_equal(@levels.length, @appender.level)
      assert_equal(0, @appender.queued_messages)
      assert(@appender.closed?)
    end

  end  # class TestEmail
end  # module TestLogging
end  # module TestAppenders

# EOF
