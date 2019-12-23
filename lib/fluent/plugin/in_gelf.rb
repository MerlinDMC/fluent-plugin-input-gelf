# encoding: utf-8
require 'time'

require 'cool.io'
require 'yajl'

require 'gelfd2'

require 'fluent/plugin/input'

module Fluent::Plugin
  class GelfInput < Fluent::Plugin::Input
    Fluent::Plugin.register_input('gelf', self)

    helpers :server, :parser, :compat_parameters

    DEFAULT_PARSER = 'json'.freeze

    def initialize
      super
    end

    desc "The value is the tag assigned to the generated events."
    config_param :tag, :string
    desc 'The port to listen to.'
    config_param :port, :integer, default: 12201
    desc 'The bind address to listen to.'
    config_param :bind, :string, default: '0.0.0.0'
    desc 'The transport protocol used to receive logs.(udp, tcp)'
    config_param :protocol_type, :enum, list: [:udp, :tcp], default: :udp
    desc 'Strip leading underscore'
    config_param :strip_leading_underscore, :bool, default: true
    desc 'remove timestamp record from document'
    config_param :remove_timestamp_record, :bool, default: true
    desc 'use client provided timestamp'
    config_param :trust_client_timestamp, :bool, default: true
    desc 'truncate client timestamp to integer'
    config_param :client_timestamp_to_i, :bool, default: false

    config_section :parse do
      config_set_default :@type, DEFAULT_PARSER
    end

    def configure(conf)
      compat_parameters_convert(conf, :parser)
      super

      @parser = parser_create
    end

    def start
      super

      listen
    end

    def shutdown
      super
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

        if @trust_client_timestamp && record.key?('timestamp')
          # Fluent "time" is made up of 2 records; time_t and nsec; you can't cast a float
          # to time; instead you must convert the remainder to a nsec INT.
          seconds = record['timestamp'].to_i
          if @client_timestamp_to_i
            time = Fluent::EventTime.new(seconds)
          else
            nsec = ((record['timestamp'].to_f  - record['timestamp'].to_i)  * 1_000_000_000).to_i
            time = Fluent::EventTime.new(seconds, nsec)
          end
          record.delete('timestamp') if @remove_timestamp_record
        else
          # if not trusting client timestamp or no timestamp provided
          time = Fluent::EventTime.now
        end

        # Postprocess recorded event
        strip_leading_underscore_(record) if @strip_leading_underscore

        emit(time, record)
      }
    rescue => e
      log.error data.dump, error: e.to_s
      log.error_backtrace
    end

    def listen
      log.info "listening gelf socket on #{@bind}:#{@port} with #{@protocol_type}"
      if @protocol_type == :tcp
        server_create(:in_tcp_server, @port, bind: @bind) do |data, conn|
          receive_data(data, conn)
        end
      else
        server_create(:in_udp_server, @port, proto: :udp, bind: @bind, max_bytes: 8192) do |data, sock|
          receive_data(data, sock)
        end
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
