#! /usr/bin/ruby
require 'rubygems'
require 'xml/smart'
require '~/projects/riddl/lib/ruby/riddl/server'
require 'securerandom'
require 'base64'
require 'uri'
require 'redis'
require 'json'



module CPEE 
  module InstanceTesting
    
    SERVER = File.expand_path(File.join(__dir__,'instantiation.xml'))

    module Helpers #{{{


      def load_testset(doc,cpee,name=nil,customization=nil) #{{{
        ins = -1
        uuid = nil

        srv = Riddl::Client.new(cpee, File.join(cpee,'?riddl-description'))
        res = srv.resource('/')
        if name
          doc.find('/*/prop:attributes/prop:info').each do |e|
            e.text = name
          end
        end
        if customization && !customization.empty?
          JSON.parse(customization).each do |e|
            begin
              customization = Typhoeus.get e['url']
              if customization.success?
                XML::Smart::string(customization.response_body) do |str|
                  doc.find("//desc:call[@id=\"#{e['id']}\"]/desc:parameters/desc:customization").each do |ele|
                    ele.replace_by str.root
                  end
                end
              end
            rescue => e
              puts e.message
              puts e.backtrace
            end
          end
        end
        # create instance
        status, response, headers = res.post Riddl::Parameter::Simple.new('info', doc.find('string(/*/prop:attributes/prop:info)'))

        if status == 200
          ins = response.first.value
          uuid = headers['CPEE_INSTANCE_UUID']

          inp = XML::Smart::string('<properties xmlns="http://cpee.org/ns/properties/2.0"/>')
          inp.register_namespace 'prop', 'http://cpee.org/ns/properties/2.0'
          # copy data from original xml to new one
          %w{executionhandler positions dataelements endpoints attributes description transformation}.each do |item|
            ele = doc.find("/*/prop:#{item}")
            inp.root.add(ele.first) if ele.any?
          end
          # expand instance data with copied information
          res = srv.resource("/#{ins}/properties").put Riddl::Parameter::Complex.new('properties','application/xml',inp.to_s)
          
          # TODO new versions
          doc.find('/*/sub:subscriptions/sub:subscription').each do |s|
            parts = []
            if id = s.attributes['id']
              parts << Riddl::Parameter::Simple.new('id', id)
            end
            parts << Riddl::Parameter::Simple.new('url', s.attributes['url'])
            s.find('sub:topic').each do |t|
              if (evs = t.find('sub:event').map{ |e| e.text }.join(',')).length > 0
                parts <<  Riddl::Parameter::Simple.new('topic', t.attributes['id'])
                parts <<  Riddl::Parameter::Simple.new('events', evs)
              end
              if (vos = t.find('sub:vote').map{ |e| e.text }.join(',')).length > 0
                parts <<  Riddl::Parameter::Simple.new('topic', t.attributes['id'])
                parts <<  Riddl::Parameter::Simple.new('votes', vos)
              end
            end
            status,body = Riddl::Client::new(cpee+ins+'/notifications/subscriptions/').post parts
          end rescue nil # in case just no subs are there
        end
        [ins, uuid]
      end #}}}
      private :load_testset

      def handle_waiting(cpee,instance,uuid,behavior,selfurl,cblist) #{{{
        if behavior =~ /^wait/
          condition = behavior.match(/_([^_]+)_/)&.[](1) || 'finished'
          cb = @h['CPEE_CALLBACK']
          puts "in handle waiting method"
          if cb
            cbk = SecureRandom.uuid
            srv = Riddl::Client.new(cpee, File.join(cpee,'?riddl-description'))
            status, response = srv.resource("/#{instance}/notifications/subscriptions/").post [
              Riddl::Parameter::Simple.new('url',File.join(selfurl,'callback',cbk)),
              Riddl::Parameter::Simple.new('topic','state'),
              Riddl::Parameter::Simple.new('events','change')
            ]
            cblist.rpush(cbk, cb)
            cblist.rpush(cbk, condition)
            cblist.rpush(cbk, instance)
            cblist.rpush(cbk, uuid)
            cblist.rpush(cbk, File.join(cpee,instance))
          end
        end
      end #}}}
      private :handle_waiting

      def handle_starting(cpee,instance,behavior) #{{{
        if behavior =~ /_running$/
          sleep 0.5
          srv = Riddl::Client.new(cpee, File.join(cpee,'?riddl-description'))
          res = srv.resource("/#{instance}/properties/state")
          puts "handle starting put request"
          status, response = res.put Riddl::Parameter::Simple.new('value','running')
          puts "status of running put request: #{status}"
        end
      end #}}}
      private :handle_starting
    
      def subscribe_all(curr_ins) #{{{
        
        conn = Redis.new(path: '/tmp/redis.sock', db: 0, id: "Instance_#{curr_ins}")
        conn.psubscribe('*') do |on|
          on.pmessage do |channel, what, message|
            
            puts "channel: #{channel}; what: #{what}; message: #{message} \n"
          
          end
        end
        conn.close
      end #}}}
    end #}}}


    class InstantiateXML < Riddl::Implementation #{{{
      include Helpers

      def response
        cpee     = @h['X_CPEE'] || @a[0]
        behavior = @a[1] ? 'fork_ready' : @p[0].value
        data     = @a[1] ? 0 : 1
        selfurl  = @a[2]
        cblist   = @a[3]
        

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
            handle_waiting cpee, instance, uuid, behavior, selfurl, cblist
            handle_starting cpee, instance, behavior
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
          if @p[0].value =~ /^wait/
            @headers << Riddl::Header.new('CPEE-CALLBACK','true')
          end
          Riddl::Parameter::Complex.new('instance', 'application/json', JSON::generate(send))
        end
      end
    end #}}}

    
      
      
    def self::implementation(opts)
      opts[:cpee]       ||= 'http://localhost:8298/'
      opts[:redis_path] ||= '/tmp/redis.sock'
      opts[:redis_db]   ||= 14
      opts[:self]       ||= "http#{opts[:secure] ? 's' : ''}://#{opts[:host]}:#{opts[:port]}/"
      opts[:cblist]       = Redis.new(path: opts[:redis_path], db: opts[:redis_db])  
      

      Proc.new do
        on resource do
          run InstantiateXML, opts[:cpee], true if post 'xmlsimple'
          on resource 'xml' do 
            run InstantiateXML, opts[:cpee], false if post 'xml'
          end
        end
      end
    end
  end
end
