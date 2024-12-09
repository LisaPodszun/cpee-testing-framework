#! /usr/bin/ruby
require 'rubygems'
require 'xml/smart'
require 'riddl/client'
require 'securerandom'
require 'base64'
require 'uri'
require 'redis'
require 'json'
require 'weel'
require 'fileutils'
module Helpers #{{{

  def self::create_test_file(instance_id)
    FileUtils.touch("./results/#{instance_id}")
  end

  def self::write_test_result(json, instance_id)
    File.open("./results/#{instance_id}", 'w') do |file| 
      file.write(json)
    end
  end

  # Loads the 5 most recent test runs
  def self::load_test_instances(instance_hash)
    instances = Dir.children('./results')
    instances.sort! {|a, b| b.to_i <=> a.to_i}
    instances = instances.slice(0, 5)
    instances.map! do |instance| 
      result = File.read("./results/#{instance}")
      instance_hash[instance] = JSON::parse(result)
    end
    instances
  end

  def post_testset(start_url, doc_url) #{{{
    ins_id = -1
    uuid = nil
    url = ""
    puts "in post testset"
    srv = Riddl::Client.new(start_url)

    res = srv.resource('/')
    puts 'Doc URL'
    p doc_url
    # create instance
    status, response, headers = res.post [Riddl::Parameter::Simple.new("behavior", "fork_ready"), Riddl::Parameter::Simple.new('url', doc_url)]
    puts 'Headers:'
    p headers
    puts 'status:'
    p status
    puts 'Response:'
    p response
    parsed_content = JSON.parse(headers['CPEE_INSTANTIATION'])
    p parsed_content
    if status == 200
      ins_id = parsed_content['CPEE-INSTANCE']
      uuid = parsed_content['CPEE-INSTANCE-UUID']
      url = parsed_content['CPEE-INSTANCE-URL']
    end
     # return instance number and instance uuid
    return ins_id, uuid, url
  end #}}}
  private :post_testset


  def handle_starting(instance, instance_url) #{{{
    base_url = File.dirname(instance_url)
    p "Base-URL in handle_starting: #{base_url}"
    srv = Riddl::Client.new(base_url, File.join(base_url, "?riddl-description"))
    res = srv.resource("/#{instance}/properties/state")
    status, response = res.put Riddl::Parameter::Simple.new('value','running')
    p "Handle starting: status: #{status}, response: #{response}"
  end #}}}
  private :handle_starting

  def subscribe_all(instance, wait, setup_done) #{{{
    #db = SQLite3::Database.open("events.db")
    puts "in subscribe all"
    event_log = {}
    #db.execute (
      #  " CREATE TABLE IF NOT EXISTS instances_events (instance INT, channel TEXT, m_content TEXT, time TEXT)"
    #)
    conn = Redis.new(path: '/tmp/redis.sock', db: 0, id: "Instance_#{instance}")
    # subscribe to all events
    seen_state_running = false
    instance_done = false
    t = Thread.new(wait) do |queue|
      conn.psubscribe('event:00:*') do |on|
        on.pmessage do |channel, event, message|
          (instance_id, cut_message) = *message.split(" ", 2)
          if instance == instance_id
            hash_message = JSON.parse cut_message
            if /event:[0-9][0-9]:position\/change/ =~ event
              puts "Current event read: #{hash_message["content"].include?("unmark")}"
            end
            if /event:[0-9][0-9]:state\/change/ =~ event
              if hash_message["instance-name"] != "subprocess"
                case hash_message["content"]["state"]
                when "running"
                  seen_state_running = true
                when "finished", "stopped"
                  instance_done  = true
                end
              end
            end
            if seen_state_running
              if /event:[0-9][0-9]:position\/change/ =~ event
                puts "Current event read in merge: #{hash_message["content"].include?("unmark")}"
              end
              if event_log.keys.include?(hash_message["timestamp"])
                puts "Already contains key"
              end
              event_log.merge!({hash_message["timestamp"] =>  {"channel" => event, "message" => hash_message}})
            end
            if instance_done
            # wait short time for remaining events to arrive
              sleep 1
              queue.enq "done"
              puts "after queue"
            end
          end
          #db.execute( "
              #    INSERT INTO instances_events (instance, channel, m_content, time) VALUES (?,?,?,?)",
              #    [instance, what, message, hash_message['timestamp']])
        end
      end
    end
    setup_done.enq "done"
    puts "after joining threads"
    return conn, event_log
  end #}}}

end #}}}
