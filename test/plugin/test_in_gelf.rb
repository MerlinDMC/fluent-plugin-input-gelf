require_relative '../test_helper'
require 'gelf'

class GelfInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  PORT = 12345
  BASE_CONFIG = %[
    port #{PORT}
    protocol_type udp
    tag gelf
  ]
  CONFIG = BASE_CONFIG + %!
    bind 127.0.0.1
  !
  IPv6_CONFIG = BASE_CONFIG + %!
    bind ::1
  !

  def create_driver(conf)
    Fluent::Test::InputTestDriver.new(Fluent::GelfInput).configure(conf)
  end

  def test_configure
    configs = {'127.0.0.1' => CONFIG}
    configs.merge!('::1' => IPv6_CONFIG) if ipv6_enabled?

    configs.each_pair { |k, v|
      d = create_driver(v)
      assert_equal PORT, d.instance.port
      assert_equal k, d.instance.bind
      assert_equal 'json', d.instance.format
    }
  end

  def test_parse
    configs = {'127.0.0.1' => CONFIG}
    # gelf-rb currently does not support IPv6 over UDP
    # configs.merge!('::1' => IPv6_CONFIG) if ipv6_enabled?

    configs.each_pair { |k, v|
      d = create_driver(v)

      tests = [
        {:short_message => 'short message', :full_message => 'full message'},
        {:short_message => 'short message', :full_message => 'full message', :timestamp => 12345678.12345}
      ]

      d.run do
        n = GELF::Notifier.new(k, PORT)

        tests.each { |test|
          n.notify!(test)
        }

        sleep 1
      end

      emits = d.emits
      assert_equal tests.length, emits.length, 'missing emitted events'
      emits.each_index { |i|
        puts emits[i].to_s
        assert_equal 'gelf', emits[i][0]
        assert_equal tests[i][:timestamp].to_i, emits[i][1] unless tests[i][:timestamp].nil?
        assert_equal tests[i][:short_message], emits[i][2]['short_message']
        assert_equal tests[i][:full_message], emits[i][2]['full_message']
      }
    }
  end
end
