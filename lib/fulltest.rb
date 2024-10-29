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
require_relative 'fixed_tests'
require_relative 'helpers'



module CPEE 
  module InstanceTesting
    
    SERVER = File.expand_path(File.join(__dir__,'instantiation.xml'))

    class FullTest < Riddl::Implementation #{{{
      include Helpers

      def response
        puts "fulltest call"
        # Own Basic Tests
        test_service_call()

        test_service_script_call()

        test_script_call()

        test_subprocess_call()

        # Basic Control Flow

        test_sequence()
       
        
        test_exclusive_choice_simple_merge()
        
        
        test_parallel_split_synchronization()
        
        
        # Advanced Branching and Synchronization
        
        test_multichoice_chained()
       
        
        test_multichoice_parallel()
        
        
        test_cancelling_discriminator()
        
        
        test_thread_split_thread_merge()
        
        
        # Multiple Instances
        
        test_multiple_instances_with_design_time_knowledge()
        
        
        test_multiple_instances_with_runtime_time_knowledge()
        
        
        test_multiple_instances_without_runtime_time_knowledge()
        
        
        test_cancelling_partial_join_multiple_instances()
        
        
        # State Based
        
        test_interleaved_routing()
      
        
        test_interleaved_parallel_routing()
        
        
        test_critical_section()
       
        
        # Cancellation and Force Completion
        
        test_cancel_multiple_instance_activity()
        
        # Iterations
        
        test_loop_posttest()
        
        test_loop_pretest()

        set = {}
        Riddl::Parameter::Complex.new('testcase_summary', 'application/json', JSON::generate(set))
      end
    end 
    
    class InstantiateTestXML < Riddl::Implementation #{{{
      include Helpers

      def response
        cpee     = @h['X_CPEE'] || @a[0]
        behavior = @a[1] ? 'fork_ready' : @p[0].value
        data     = @a[1] ? 0 : 1
        selfurl  = @a[2]
        

        tdoc = if @p[data].additional =~ /base64/
          Base64.decode64(@p[data].value.read)
        else
          @p[data].value.read
        end
        
        tdoc = XML::Smart.string(tdoc)
        tdoc.register_namespace 'desc', 'http://cpee.org/ns/description/1.0'
        tdoc.register_namespace 'prop', 'http://cpee.org/ns/properties/2.0'
        tdoc.register_namespace 'sub', 'http://riddl.org/ns/common-patterns/notifications-producer/2.0'

               
        if (instance, uuid = load_testset(tdoc,cpee)).first == -1
          @status = 500
        else
          EM.defer do
            handle_starting cpee, instance
          end
          EM.defer do
            subscribe_all instance
          end 
          send = {
            'CPEE-INSTANCE' => instance,
            'CPEE-INSTANCE-URL' => File.join(cpee,instance),
            'CPEE-INSTANCE-UUID' => uuid,
            'CPEE-BEHAVIOR' => behavior
          }
          
          Riddl::Parameter::Complex.new('instance', 'application/json', JSON::generate(send))
        end
      end
    end
    #}}}
      
    def self::implementation(opts)
      p "Calling implementation with opts: #{opts}"
      opts[:cpee]       ||= 'http://localhost:8298/'
      opts[:redis_path] ||= '/tmp/redis.sock'
      opts[:redis_db]   ||= 14
      opts[:self]       ||= "http#{opts[:secure] ? 's' : ''}://#{opts[:host]}:#{opts[:port]}/"
      opts[:cblist]       = Redis.new(path: opts[:redis_path], db: opts[:redis_db])  
      

      Proc.new do
        on resource do
          on resource 'fulltest' do
            run FullTest if get
          end
        end
      end
    end
  end
end