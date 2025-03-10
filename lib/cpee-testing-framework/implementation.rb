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
        Riddl::Parameter::Complex.new('results','application/json', JSON::generate(@a[0]))
      end
    end #}}}

    class FullTest < Riddl::Implementation #{{{
      include TestCases
      include Helpers

      def response
        pp @p
        data = @a[0]
        testinstances = @a[1]
        if @p[1]
          testfile = @p[1].value.read 
        else
          testfile = nil
        end
        settings = JSON.parse(@p[0].value.read) 
        
        if settings['test'] == 'all' 
          tests = [
            :service_call,
            :service_script_call,
            :script_call,
            :subprocess_call,
            :sequence,
            :exclusive_choice_simple_merge,
            :parallel_split_and_synchronization,
            :multi_choice_chained,
            #:multi_choice_parallel,  --> not possible in rust
            :cancelling_discriminator,
            :thread_split_thread_merge,
            :multiple_instances_with_design_time_knowledge,
            :cancelling_partial_join_multiple_instances,
            :interleaved_routing,
            :interleaved_parallel_routing,
            :critical_section,
            :cancel_multiple_instance_activity,   
            :loop_posttest,
            :loop_pretest
          ]
        elsif settings['test'] == 'allAalst'
          tests = [
          :sequence,
          :exclusive_choice_simple_merge,
          :parallel_split_and_synchronization,
          :multi_choice_chained,
          #:multi_choice_parallel,  --> not possible in rust
          :cancelling_discriminator,
          :thread_split_thread_merge,
          :multiple_instances_with_design_time_knowledge,
          :cancelling_partial_join_multiple_instances,
          :interleaved_routing,
          :interleaved_parallel_routing,
          :critical_section,
          :cancel_multiple_instance_activity,   
          :loop_posttest,
          :loop_pretest
          ]
        elsif settings['test'] == 'allCPEE'
          tests = [
            :service_call,
            :service_script_call,
            :script_call,
            :subprocess_call 
          ]
        elsif settings['test'].split('.')[-1] == 'xml'
          tests = [:custom]
          testfile = augment_testset(testfile)
        else
          tests = [settings['test'].to_sym]
        end

        if testinstances.keys.empty? 
          i = 0
        else 
          instance_ids_desc = testinstances.keys.sort {|a, b| b.to_i <=> a.to_i}
          i = instance_ids_desc[0].to_i + 1
        end
        i = i.to_s
        testinstances[i] = {
          :status => :running,
          :currently_running => '',
          :total => tests.length,
          :finished => 0,
          :results => {},
          :start => Time.now,
          :settings => settings
        }
        
        testinstance = testinstances[i]

        p testinstances.keys
        # Own Basic Tests

        Thread.new do
          Helpers::create_test_file(i)
          tests.each do |testname|
            if testname == :custom
              testinstance[:xml] = testfile
            end
            testinstance[testname] = {}
            testinstance[testname][:start] = Time.now
            testinstance[:currently_running] = testname
            send testname, data, testinstance, settings
            testinstance[testname][:end] = Time.now
            testinstance[testname][:duration_in_seconds] = testinstance[testname][:end] - testinstance[testname][:start]
            testinstance[:finished] += 1
          end
          testinstance[:status] = :finished
          json = JSON::generate(testinstance)
          Helpers::write_test_result(json, i)
        end
        Riddl::Parameter::Simple.new('instance', i)
      end
    end #}}}

    class Configuration < Riddl::Implementation #{{{
      def response
        Riddl::Parameter::Complex.new("configuration", "application/json", File.open("./config.json"))
      end
    end #}}}

    class Instances < Riddl::Implementation #{{{
      def response
        puts "In response for instances"
        Riddl::Parameter::Complex.new("instances", "application/json", @a[0].to_json)
      end
    end #}}}

    class HandleEvents < Riddl::Implementation # {{{
      include Helpers

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
        # filter out empty unmarks
        if topic == 'position' && eventname =='change'
          if event['content'].key? 'unmark' 
            if event['content']['unmark'].empty?
              return
            end
          end
        end

        if data[event['instance-url']][:log].key? event['timestamp']
        end
        data[event['instance-url']][:log].merge!({event['timestamp'] =>   {'channel' => topic +'/'+ eventname, 'message' => event}})

        # Seen the state finished
        if topic == 'state' && event['content']['state'] == 'finished'
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
      Helpers::load_test_instances(opts[:testinstances])

      Proc.new do
        interface 'events' do
          run HandleEvents, opts[:data] if post 'event'
        end
        interface 'testing' do
          run FullTest, opts[:data], opts[:testinstances] if post 'test-config'
          run Instances, opts[:testinstances] if get
          on resource '\d+' do |res|
            run Status, opts[:testinstances][res[:r].last] if get
          end
          on resource 'configuration' do
            run Configuration if get
          end
        end
      end
    end
  end #}}}

end
