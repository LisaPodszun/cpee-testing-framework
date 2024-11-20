#! /usr/bin/ruby
require 'rubygems'
require 'xml/smart'
require '~/projects/riddl/lib/ruby/riddl/server'
require 'securerandom'
require 'base64'
require 'uri'
require 'redis'
require 'json'
require 'sqlite3'
require_relative 'test_cases'


module CPEE 
  module InstanceTesting
    
    SERVER = File.expand_path(File.join(__dir__,'instantiation.xml'))
    
    @event_log = {}

    class Status < Riddl::Implementation #{{{
      def response
        Riddl::Parameter::Complex.new('results','application/json', JSON::encode(@a[0]))
      end  
    end

    class FullTest < Riddl::Implementation #{{{
      include Helpers
      include TestCases

      def response
        data = @a[0]
        testinstances = @a[1]

        tests = [
          :test_service_call,
#          :test_service_script_call
        ]          

        i  = 0
        i += 1 while testinstances.has_key(i)
        testinstances[i] = {
          :status => :running,
          :currently_running => '',
          :total => tests.length
          :finished => 0
          :results => {}
        } 
        testinstance = testinstances[i]  
        
        puts "fulltest call"
        # Own Basic Tests

        data << Queue.new
        Thread.new do
          test.each do |testname|
            testinstance[testname] = {}
            testinstance[testname][:start] = Time.now
            testinstance[:currently_running] = testname
            send testname, data, testinstance[testname]
            testinstance[testname][:end] = Time.now
            testinstance[testname][:duration_in_seconds] = testinstance[testname][:end] - testinstance[testname][:start]
            testinstance[:finished] += 1
          end
          testinstance[:status] = :finished
        end
        Riddl::Parameter::Simple.new('instance', i)
      end
    end 

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
        
        data[event['cpee-instance-url']][:log][event['timestamp']] = event
        
        if topic =~ 'state' && eventname == 'finished'
          data[event['cpee-instance-url']][:end].continue
        end
      end
    end 
    # }}}
      
    def self::implementation(opts)
      opts[:cpee]       ||= 'http://localhost:8298/'
      opts[:redis_path] ||= '/tmp/redis.sock'
      opts[:redis_db]   ||= 0
      opts[:redis_pid]  ||= 'redis.pid'
      opts[:self]       ||= "http#{opts[:secure] ? 's' : ''}://#{opts[:host]}:#{opts[:port]}/"
      opts[:cblist]       = Redis.new(path: opts[:redis_path], db: opts[:redis_db])  

      opts[:data] = {}
      opts[:testinstances] = {}
      
      Proc.new do
        on resource do
          on resource 'fulltest' do
            run FullTest, opts[:data], opts[:testinstances] if get
            run HandleEvents, opts[:data] if post 'fulltest'
            on resource '\d+' do |res|
              run Status, opts[:testinstances][res[:r].last] if get
            end  
          end
        end
      end
    end
  end
end
