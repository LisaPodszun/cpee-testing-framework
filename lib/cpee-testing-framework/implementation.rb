#! /usr/bin/ruby
require 'rubygems'
require 'xml/smart'
require 'riddl/client'
require 'riddl/server'
require 'securerandom'
require 'base64'
require 'uri'
require 'redis'
require 'json'
require_relative 'test_cases'


module CPEE
  module InstanceTesting

    SERVER = File.expand_path(File.join(__dir__,'implementation.xml'))

    @event_log = {}

    class Status < Riddl::Implementation #{{{
      def response
        p @a[0]
        Riddl::Parameter::Complex.new('results','application/json', JSON::generate(@a[0]))
      end
    end #}}}

    class FullTest < Riddl::Implementation #{{{
      include Helpers
      include TestCases

      def response
        data = @a[0]
        testinstances = @a[1]
        settings = JSON.parse(@p[0].value.read)
        if settings['test'] == 'all'
          tests = [
            :service_call,
        #   :service_script_call
          ]
        else
          tests = [settings['test'].to_sym]
        end

        i  = 0
        i += 1 while testinstances.key?(i)
        testinstances[i] = {
          :status => :running,
          :currently_running => '',
          :total => tests.length,
          :finished => 0,
          :results => {}
        }
        
        testinstance = testinstances[i]

        puts "fulltest call"
        # Own Basic Tests

        Thread.new do
          tests.each do |testname|
            testinstance[testname] = {}
            testinstance[testname][:start] = Time.now
            testinstance[:currently_running] = testname
            send testname, data, testinstance, settings
            testinstance[testname][:end] = Time.now
            testinstance[testname][:duration_in_seconds] = testinstance[testname][:end] - testinstance[testname][:start]
            testinstance[:finished] += 1
          end
          testinstance[:status] = :finished
        end
        Riddl::Parameter::Simple.new('instance', i)
      end
    end #}}}

    class Configuration < Riddl::Implementation #{{{
      def response
        Riddl::Parameter::Complex.new("configuration", "application/json", File.open("./config.json"))
      end
    end #}}}

    class HandleEvents < Riddl::Implementation # {{{
      def response
        data = @a[0]

        type  = @p[0].value
        # topic = state, dataelements, activity, ...
        topic = @p[1].value
        # eventname = change, calling, manipulating, ...
        eventname = @p[2].value
        # value
        event = JSON.parse(@p[3].value.read)
        if topic == 'status'
          data[event['instance-url']][:resource_utilization] << event
          return
        end
        if topic == 'transformation' || topic == 'description' || topic == 'endpoints'
          return
        end

        if data[event['instance-url']][:log].key? event['timestamp']
          p "Topic: #{topic}"
          p "Event: #{eventname}"
          p "content: #{event}"

          p "ALREADY CONTAINS THE TIMESTAMP"
          p "Overwriting value: #{data[event['instance-url']][:log][event['timestamp']]}"
        end
        data[event['instance-url']][:log].merge!({event['timestamp'] =>   {'channel' => topic +'/'+ eventname, 'message' => event}})

        if topic == 'state' && event['content']['state'] == 'finished'
          puts "seen the state finished"
          Thread.new do 
            sleep 5
            data[event['instance-url']][:end].continue
          end
        end
      end
    end # }}}

    def self::implementation(opts) #{{{
      opts[:cpee]       ||= 'http://localhost:8298/'
      opts[:redis_path] ||= '/tmp/redis.sock'
      opts[:redis_db]   ||= 0
      opts[:redis_pid]  ||= 'redis.pid'
      opts[:self]       ||= "http#{opts[:secure] ? 's' : ''}://#{opts[:host]}:#{opts[:port]}/"
      opts[:cblist]       = Redis.new(path: opts[:redis_path], db: opts[:redis_db])

      opts[:data] = {}
      opts[:testinstances] = {}

      Proc.new do
        interface 'events' do
          run HandleEvents, opts[:data] if post 'event'
        end

        interface 'testing' do
          run FullTest, opts[:data], opts[:testinstances] if post 'settings'

          on resource '\d+' do |res|
            p "On resource inst id #{res[:r]}"
            p "Opts instances:"
            p opts[:testinstances]
            p "Access:"
            p opts[:testinstances][res[:r].last.to_i]
            run Status, opts[:testinstances][res[:r].last.to_i] if get
          end
          on resource 'configuration' do
            run Configuration if get
          end
        end
      end
    end
  end #}}}

end
