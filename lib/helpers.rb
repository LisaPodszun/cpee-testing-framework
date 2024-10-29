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

module Helpers #{{{

  @@cpee = "http://localhost:8298/"

  def post_testset(doc) #{{{
    ins = -1
    uuid = nil

    srv = Riddl::Client.new(@@cpee, File.join(@@cpee,'?riddl-description'))

    res = srv.resource('/')
   
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
    end
     # return instance number and instance uuid 
    [ins, uuid]
  end #}}}
  private :post_testset

  
  def handle_starting(instance) #{{{
    sleep 0.5
    srv = Riddl::Client.new(cpee, File.join(@@cpee,'?riddl-description'))
    res = srv.resource("/#{instance}/properties/state")
    status, response = res.put Riddl::Parameter::Simple.new('value','running')
  end #}}}
  private :handle_starting

  def subscribe_all(instance) #{{{
    #db = SQLite3::Database.open("events.db")
    event_log = {}
    #db.execute (
    #  " CREATE TABLE IF NOT EXISTS instances_events (instance INT, channel TEXT, m_content TEXT, time TEXT)"
    #)
    conn = Redis.new(path: '/tmp/redis.sock', db: 0, id: "Instance_#{instance}")
    # subscribe to all events
    seen_state_running = false
    instance_done = false
    conn.psubscribe('event:00:*') do |on|
      on.pmessage do |channel, what, message|
        (instance_id, message) = *message.split(" ", 2);
        if instance == instance_id  
          hash_message = JSON.parse cut_message
          if what == "event:00:state/change"
            case hash_message["content"]["state"] 
            when "running"
              seen_state_running = true
            when "finished", "stopped"
              instance_done  = true
            end
          end
          if seen_state_running
            event_log.store(hash_message["timestamp"], {channel: what, message: hash_message})
          end
          if instance_done
            # wait short time for remaining events to arrive
            sleep 1
            queue.enq "done"
          end
        end
        #db.execute( "
        #    INSERT INTO instances_events (instance, channel, m_content, time) VALUES (?,?,?,?)", 
        #    [instance, what, message, hash_message['timestamp']])
      end
    end
    [conn, event_log]
  end #}}}

end #}}}