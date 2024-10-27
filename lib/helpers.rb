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

  def handle_waiting(instance,uuid,behavior,selfurl,cblist) #{{{
    if behavior =~ /^wait/
      condition = behavior.match(/_([^_]+)_/)&.[](1) || 'finished'
      cb = @h['CPEE_CALLBACK']
      puts "in handle waiting method"
      if cb
        cbk = SecureRandom.uuid
        srv = Riddl::Client.new(@@cpee, File.join(@@cpee,'?riddl-description'))
        status, response = srv.resource("/#{instance}/notifications/subscriptions/").post [
          Riddl::Parameter::Simple.new('url',File.join(selfurl,'callback',cbk)),
          Riddl::Parameter::Simple.new('topic','state'),
          Riddl::Parameter::Simple.new('events','change')
        ]
        cblist.rpush(cbk, cb)
        cblist.rpush(cbk, condition)
        cblist.rpush(cbk, instance)
        cblist.rpush(cbk, uuid)
        cblist.rpush(cbk, File.join(@@cpee,instance))
      end
    end
  end #}}}
  private :handle_waiting

  def handle_starting(instance,behavior) #{{{
    if behavior =~ /_running$/
      sleep 0.5
      srv = Riddl::Client.new(cpee, File.join(@@cpee,'?riddl-description'))
      res = srv.resource("/#{instance}/properties/state")
      status, response = res.put Riddl::Parameter::Simple.new('value','running')
    end
  end #}}}
  private :handle_starting

  def subscribe_all(curr_ins) #{{{
    db = SQLite3::Database.open("events.db")
    db.execute (
      " CREATE TABLE IF NOT EXISTS instances_events (instance INT, channel TEXT, m_content TEXT, time TEXT)"
    )
    conn = Redis.new(path: '/tmp/redis.sock', db: 0, id: "Instance_#{curr_ins}")
    conn.psubscribe('*') do |on|
      on.pmessage do |channel, what, message|
        cut_message = message.slice((message.index("{"))..-1)
        hash_message = JSON.parse cut_message
        db.execute( "
            INSERT INTO instances_events (instance, channel, m_content, time) VALUES (?,?,?,?)", 
            [curr_ins, what, message, hash_message['timestamp']])
      end
    end
    db.close
    conn.close
  end #}}}

end #}}}