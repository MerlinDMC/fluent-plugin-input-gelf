# encoding: utf-8
require 'time'

require 'cool.io'
require 'yajl'

require 'fluent/input'

module Fluent
  class GelfInput < Fluent::Input
    Fluent::Plugin.register_input('gelf', self)

    def initialize
      super
      require 'fluent/plugin/socket_util'
      require 'gelfd2'
    end

    desc "The value is the tag assigned to the generated events."
    config_param :tag, :string
    desc 'The format of the payload.'
    config_param :format, :string, default: 'json'
    desc 'The port to listen to.'
    config_param :port, :integer, default: 12201
    desc 'The bind address to listen to.'
    config_param :bind, :string, default: '0.0.0.0'
    desc 'The transport protocol used to receive logs.(udp, tcp)'
    config_param :protocol_type, default: :udp do |val|
      case val.downcase
      when 'tcp'
        :tcp
      when 'udp'
        :udp
      else
        raise ConfigError, "gelf input protocol type should be 'tcp' or 'udp'"
      end
    end
    config_param :blocking_timeout, :time, default: 0.5
    desc 'Strip leading underscore'
    config_param :strip_leading_underscore, :bool, default: true

    def configure(conf)
      super

      @parser = Plugin.new_parser(@format)
      @parser.configure(conf)
    end

    def start
      @loop = Coolio::Loop.new
      @handler = listen(method(:receive_data))
      @loop.attach(@handler)

      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @loop.watchers.each { |w| w.detach }
      @loop.stop
      @handler.close
      @thread.join
    end

    def run
      @loop.run(@blocking_timeout)
    rescue
      log.error 'unexpected error', error: $!.to_s
      log.error_backtrace
    end

    def receive_data(data, addr)
      begin
        msg = Gelfd2::Parser.parse(data)
      rescue => e
        log.warn 'Gelfd failed to parse a message', error: e.to_s
        log.warn_backtrace
      end

      # Gelfd parser will return nil if it received and parsed a non-final chunk
      return if msg.nil?

      @parser.parse(msg) { |time, record|
        unless time && record
          log.warn "pattern not match: #{msg.inspect}"
          return
        end

        # Use the recorded event time if available
        time = record.delete('timestamp').to_i if record.key?('timestamp')

        # Postprocess recorded event
        strip_leading_underscore_(record) if @strip_leading_underscore

        emit(time, record)
      }
    rescue => e
      log.error data.dump, error: e.to_s
      log.error_backtrace
    end

    def listen(callback)
      log.info "listening gelf socket on #{@bind}:#{@port} with #{@protocol_type}"
      if @protocol_type == :tcp
        Coolio::TCPServer.new(@bind, @port, SocketUtil::TcpHandler, log, "\n", callback)
      else
        @usock = SocketUtil.create_udp_socket(@bind)
        @usock.bind(@bind, @port)
        SocketUtil::UdpHandler.new(@usock, log, 8192, callback)
      end
    end

    def emit(time, record)
      router.emit(@tag, time, record)
    rescue => e
      log.error 'gelf failed to emit', error: e.to_s, error_class: e.class.to_s, tag: @tag, record: Yajl.dump(record)
    end

    private

    def strip_leading_underscore_(record)
      record.keys.each { |k|
        next unless k[0,1] == '_'
        record[k[1..-1]] = record.delete(k)
      }
    end
  end
end
