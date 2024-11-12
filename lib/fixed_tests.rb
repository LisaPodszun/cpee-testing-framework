require_relative 'helpers'



module FixedTests
    
    module TestHelpers
        NON_TESTABLE_ENTRIES = ["instance-url","instance","instance-uuid","content_attributes_uuid","content_at_uuid",
         "timestamp", "uuid", "ecid", "content_ecid", "content_activity-uuid", "content_unmark_uuid"]
        
        def run_test_case(doc, weel)
            instance, uuid = post_testset(doc)
            wait = Queue.new
            connection, event_log  = subscribe_all(instance, wait)
            handle_starting(instance)
            wait.deq
            connection.close
            # sort by timestamp from weel
            event_log.sort_by{|key, value| key}
            index = 0
            event_log.each do |entry|
                entry[0] = index
                index += 1
            end
            event_log.to_h
        end

        
        def structure_test(rust_log_entry, ruby_log_entry)
            # holds all keys ruby - rust
            dif_ruby_to_rust = []
            # holds all keys rust - ruby
            dif_rust_to_ruby = []
            
            dif_ruby_to_rust = hash_structure_test([], ruby_log_entry, rust_log_entry)
            
            dif_rust_to_ruby = hash_structure_test([], rust_log_entry, ruby_log_entry)
            
            [dif_rust_to_ruby, dif_ruby_to_rust]
        end

        def hash_structure_test(path, hash_1, hash_2)
            diff = []
            # test hash_1 > hash_2 
            hash_1.each do |key, value|
                path << key
                if !hash_2.key?(key)
                    diff << path.join("_")
                elsif value.class == Hash
                    diff << hash_structure_test(path, value, hash_2[key])
                end
                path.pop
            end
            diff.flatten
        end
        
        def content_test(rust_log_entry, dif_rust_to_ruby, ruby_log_entry, dif_ruby_to_rust)
            # save all common keys and if they hold the same or different values
            dif_content_keys = hash_content_test([], rust_log_entry, ruby_log_entry, dif_rust_to_ruby, dif_ruby_to_rust)
        end
        
        def hash_content_test(path, hash_1, hash_2, dif_rust_to_ruby, dif_ruby_to_rust)
            diff = []
            # test hash_1 > hash_2 
            hash_1.each do |key, value|
                path << key
                if !(NON_TESTABLE_ENTRIES.include?(path.join("_")) || dif_rust_to_ruby.include?(path.join("_")) || dif_ruby_to_rust.include?(path.join("_")) || value.class == Hash)
                    if (value != hash_2[key])
                        diff << path.join("_")
                    end
                elsif value.class == Hash
                    diff << (hash_content_test(path, value, hash_2[key], dif_rust_to_ruby, dif_ruby_to_rust))
                end
                path.pop
            end
            diff.flatten
        end

        def completeness_test(rust_log, ruby_log)
            events_rust = {}
            events_ruby = {}
            # event difference of amounts  ruby - rust
            events_dif = {}
            missing_events_ruby = []
            missing_events_rust = []
            # store {event_type: amount}
            rust_log.each do |key, value|
                channel = value["channel"].split(':')[2]
                if !events_rust.key?(channel)
                    events_rust.store(channel, 0)
                end
                events_rust[channel] += 1
            end
            # store {event_type: amount}
            ruby_log.each do |key, value|
                channel = value["channel"].split(':')[2]
                if !events_ruby.key?(channel)
                    events_ruby.store(channel, 0)
                end
                events_ruby[channel] += 1
            end
            # calculate dif ruby - rust for each event
            events_ruby.each do |key, value|
                if events_rust.key?(key)
                    events_dif = events_dif.merge({key => (value - events_rust[key])})
                else
                    events_dif = events_dif.merge({key =>  value})
                    missing_events_rust << key
                end
            end
            # check for missing events from other event log
            events_rust.each do |key, value|
                if !events_ruby.key?(key)
                    events_dif = events_dif.merge({key => -value})
                    missing_events_ruby << key
                end
            end
            return events_dif, missing_events_ruby, missing_events_rust
        end

        def extract_cf_events(log)
            cf_events = {}
            index = 0
            log.values.each do |entry|
                tmp = entry["channel"].split(":")
                channel = tmp[2]
                if (["position/change", "gateway/decide", "gateway/join", "gateway/split"].include?(channel) && entry["message"]["instance-name"] != "subprocess")
                    cf_events =  cf_events.merge({index => entry})
                    index +=1
                end
            end
            cf_events 
        end

        def events_match?(ruby_log_entry, rust_log_entry)
            event_type = ruby_log_entry["channel"]
            channel = event_type.split(":")[2]
            case channel
            when "state/change"
                rust_log_entry["message"]["content"]["state"] == ruby_log_entry["message"]["content"]["state"]
            when "position/change"
                content_keys = ruby_log_entry["message"]["content"].keys
                if content_keys.include?("at")
                    if rust_log_entry["message"]["content"].keys.include?("at")
                        ruby_log_entry["message"]["content"]["at"] == rust_log_entry["message"]["content"]["at"]
                    else
                        false
                    end
                elsif content_keys.include?("after")
                    if rust_log_entry["message"]["content"].keys.include?("after")
                        ruby_log_entry["message"]["content"]["after"] == rust_log_entry["message"]["content"]["after"]
                    else
                        false
                    end
                elsif content_keys.include?("unmark")
                    if rust_log_entry["message"]["content"].keys.include?("unmark")
                        ruby_log_entry["message"]["content"]["unmark"] == rust_log_entry["message"]["content"]["unmark"]
                    else
                        false
                    end
                end
            when "gateway/decide"
                rust_log_entry["message"]["content"]["code"] == ruby_log_entry["message"]["content"]["code"]

            when "gateway/join"
                rust_log_entry["message"]["content"]["branches"] == ruby_log_entry["message"]["content"]["branches"]
                
            when "gateway/split"
                rust_log_entry["message"]["name"] == ruby_log_entry["message"]["name"]

            when "dataelements/change"
                dataelements = (rust_log_entry["message"]["content"]["changed"] == ruby_log_entry["message"]["content"]["changed"])
                values = (rust_log_entry["message"]["content"]["values"] == ruby_log_entry["message"]["content"]["values"])
                dataelements && values

            when "activity/calling"
                rust_log_entry["message"]["content"]["activity"] == ruby_log_entry["message"]["content"]["activity"] 

            when "activity/manipulating"
                rust_log_entry["message"]["content"]["activity"] == ruby_log_entry["message"]["content"]["activity"] 

            when "activity/receiving"
                rust_log_entry["message"]["content"]["activity"] == ruby_log_entry["message"]["content"]["activity"] 
            when "activity/done"
                rust_log_entry["message"]["content"]["activity"] == ruby_log_entry["message"]["content"]["activity"] 
            when "status/resource_utilization"
                true
            end
        end

        def match_logs(rust_log, ruby_log, missing_events_ruby, missing_events_rust)
            rust_index = 0
            after_last_rust_match = 0
            after_last_ruby_match = 0
            ruby_index = 0
            # ruby_log_entry => rust_log_entry
            ruby_log_tags = {}
            # rust_log_entry => ruby_log_entry 
            rust_log_tags = {}
            while (ruby_index < ruby_log.length)
                str_ruby_index = ruby_index.to_s
                str_rust_index = rust_index.to_s
                ruby_event_type = ruby_log[str_ruby_index]["channel"].split(":")[2]
                rust_event_type = rust_log[str_rust_index]["channel"].split(":")[2]
                if missing_events_rust.include?(ruby_event_type)
                    ruby_log_tags = ruby_log_tags.merge({ruby_index => "only_ruby"})
                    ruby_index += 1
                elsif rust_event_type == ruby_event_type
                    if events_match?(rust_log[str_rust_index],ruby_log[str_ruby_index])
                        ruby_log_tags = ruby_log_tags.merge({ruby_index => rust_index})
                        rust_log_tags = rust_log_tags.merge({rust_index => ruby_index})
                        ruby_index += 1
                        rust_index += 1
                        after_last_rust_match = rust_index
                    else
                        rust_index += 1
                        if (rust_index == rust_log.length)
                            ruby_log_tags = ruby_log_tags.merge({ruby_index => "no_match"})
                            rust_index = after_last_rust_match
                            ruby_index += 1
                        end
                    end
                else
                    if missing_events_ruby.include?(rust_event_type)
                        rust_log_tags = rust_log_tags.merge({rust_index => "only_rust"})
                        rust_index += 1
                    else
                        ruby_log_tags = ruby_log_tags.merge({ruby_index => "no_match"})
                        ruby_index += 1
                    end
                end
            end
            rust_index = 0
            while (rust_index < rust_log.length)
                str_rust_index = rust_index.to_s
                event_type = rust_log[str_rust_index]["channel"].split(":")[2]
                if missing_events_ruby.include?(event_type)
                    rust_log_tags = rust_log_tags.merge({rust_index => "only_rust"})
                    rust_index += 1
                elsif rust_log_tags.keys.include?(rust_index)
                    rust_index += 1
                else
                    rust_log_tags = rust_log_tags.merge({rust_index => "no_match"})
                    rust_index += 1
                end
            end
            [ruby_log_tags, rust_log_tags]
        end
     #{{{  # control flow tests
        def cf_service_call(cf_events)
            passed = 0
            if cf_events.length == 3
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 1
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    end
                end
                (passed == 0)
            else
                # TODO: no control flow test possible, missing events
                false
            end
        end

        def cf_service_script_call(cf_events)
            passed = 0
            if cf_events.length == 3
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 1
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_script_call(cf_events)
            passed = 0
            if cf_events.length == 3
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 1
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_subprocess_call(cf_events)
            passed = 0
            if cf_events.length == 3
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 1
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_sequence(cf_events)
            passed = 0
            if cf_events.length == 7
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 1
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a1")
                            passed += 1
                        end
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 4
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a2")
                            passed += 1
                        end
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    end        
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_exclusive_choice_simple_merge(cf_events)
            passed = 0
            ecid = 0
            if cf_events.length == 6
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1 
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/)
                            passed += 1
                        end
                    when 2 
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 4
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 5 
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                            passed += 1
                        end
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_parallel_split_synchronization(cf_events)
            passed = 0
            ecid = 0
            if cf_events.length == 11
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1
                        if !(value["message"]["content"].key?("at") && ["a1", "a2"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("at") && ["a1", "a2"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a1")
                            passed += 1
                        end
                    when 4
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a1")
                            passed += 1
                        end
                    when 5 
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a2")
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a2")
                            passed += 1
                        end
                    when 7
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 8
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 9
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a3")
                            passed += 1
                        end
                    when 10
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a3")
                            passed += 1
                        end
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_multichoice_chained(cf_events)
            passed = 0
            ecid = 0
            if cf_events.length == 11
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1 
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/)
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 4
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/)
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 7
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 8
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a2")
                            passed += 1
                        end
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 9
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 10
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    end        
                end
                (passed == 0)
            else
                false
            end
        end
        
        # TODO : fix this test, see if it can execute
        def cf_multichoice_parallel(cf_events)

            passed = 0
            ecid = 0
            if cf_events.length == 11
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1 
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/)
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 4
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/)
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 7
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 8
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a2")
                            passed += 1
                        end
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 9
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 10
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    end        
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_cancelling_discriminator(cf_events)
            passed = 0
            ecid = 0
            if cf_events.length == 10
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1 
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 4
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 6    
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 7
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 8
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 9
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a3")
                            passed += 1
                        end
                    end       
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_thread_split_thread_merge(cf_events)
            passed = 0
            ecid = 0
            if cf_events.length == 18
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a4")
                            passed += 1
                        end
                    when 1
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a4")
                            passed += 1
                        end
                    when 2
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 3
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a4")
                            passed += 1
                        end
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 4
                        if !(value["message"]["content"].key?("at") && ["a1","a2"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("at") && ["a1","a2"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("wait") && ["a1","a2", "a3"].include?(value["message"]["content"]["wait"][0]["position"]))
                            passed += 1
                        end
                    when 7
                        if !(value["message"]["content"].key?("wait") && ["a1","a2", "a3"].include?(value["message"]["content"]["wait"][0]["position"]))
                            passed += 1
                        end                               
                    when 8
                        if !(value["message"]["content"].key?("after") && ["a1","a2","a3"].include?(value["message"]["content"]["after"][0]["position"]))
                            passed += 1
                        end
                    when 9
                        if !(value["message"]["content"].key?("unmark") && ["a1","a2","a3"].include?(value["message"]["content"]["unmark"][0]["position"]))
                            passed += 1
                        end   
                    when 10
                        if !(value["message"]["content"].key?("after") && ["a1","a2","a3"].include?(value["message"]["content"]["after"][0]["position"]))
                            passed += 1
                        end
                    when 11
                        if !(value["message"]["content"].key?("unmark") && ["a1","a2","a3"].include?(value["message"]["content"]["unmark"][0]["position"]))
                            passed += 1
                        end
                    when 12
                        if !(value["message"]["content"].key?("after") && ["a1","a2","a3"].include?(value["message"]["content"]["after"][0]["position"]))
                            passed += 1
                        end
                    when 13
                        if !(value["message"]["content"].key?("unmark") && ["a1","a2","a3"].include?(value["message"]["content"]["unmark"][0]["position"]))
                            passed += 1
                        end
                    when 14
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 15
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a5")
                            passed += 1
                        end
                    when 16
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"][0]["position"] == "a5")
                            passed += 1
                        end
                    when 17
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"][0]["position"] == "a5")
                            passed += 1
                        end
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        # runs with error, check with Juergen
        def cf_multiple_instances_with_design_time_knowledge(cf_events)        
        end

        # not possible in comparison test
        def cf_multiple_instances_with_runtime_time_knowledge(cf_events)
        end

        # not possible in comparison test
        def cf_multiple_instances_without_runtime_time_knowledge(cf_events)
        end

        # ask because extra event sent
        def cf_cancelling_partial_join_multiple_instances(cf_events)
            passed = 0
            ecid = 0
            if cf_events.length == 22
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1 
                        if !(value["message"]["content"].key?("at") && ["a1", "a2", "a3", "a4", "a5"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("at") && ["a1", "a2", "a3", "a4", "a5"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("at") && ["a1", "a2", "a3", "a4", "a5"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 4
                        if !(value["message"]["content"].key?("at") && ["a1", "a2", "a3", "a4", "a5"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("at") && ["a1", "a2", "a3", "a4", "a5"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a5")
                            passed += 1
                        end
                    when 7
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a5")
                            passed += 1
                        end
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a8")
                            passed += 1
                        end
                    when 8   
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 9
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 10
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 11
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a1")
                            passed += 1
                        end
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a6")
                            passed += 1
                        end
                    when 12   
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a4")
                            passed += 1
                        end
                    when 13
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a4")
                            passed += 1
                        end
                    when 14
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 15
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a3")
                            passed += 1
                        end
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a7")
                            passed += 1
                        end
                    when 16
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a6")
                            passed += 1
                        end
                    when 17
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a6")
                            passed += 1
                        end
                    when 18
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a7")
                            passed += 1
                        end
                    when 19
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a8")
                            passed += 1
                        end
                    when 20    
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 21
                        # strange extra position/change event sent
                        if !(value["message"]["content"].key?("unmark"))
                            passed += 1
                        end
                    end
                end
                (passed == 0)
            else
                false
            end

        end

        def cf_interleaved_routing(cf_events)
            passed = 0
            if cf_events.length == 11
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"]== "a5")
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a5")
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a5")
                            passed += 1
                        end
                    when 4
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"]== "a6")
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a6")
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a6")
                            passed += 1
                        end
                    when 7
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 8
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a1")
                            passed += 1
                        end
                    when 9
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a1")
                            passed += 1
                        end
                    when 7
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 8
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a2")
                            passed += 1
                        end
                    when 9
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a2")
                            passed += 1
                        end
                    when 10
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end    
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_interleaved_parallel_routing(cf_events)
            passed = 0
            if cf_events.length == 11
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a2")
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a2")
                            passed += 1
                        end
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 4 
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a1")
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a1")
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                            passed += 1
                        end
                    when 7
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a3")
                            passed += 1
                        end
                    when 8
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a3")
                            passed += 1
                        end
                    when 9
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 10
                        # strange extra event
                        if !(value["message"]["content"].key?("unmark"))
                            passed += 1
                        end        
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        def cf_critical_section(cf_events)
            passed = 0
            ecid = 0 
            if cf_events.length == 9
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a1")
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a1")
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"]=="a1")
                            passed += 1
                        end
                    when 4 
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"]=="a2")
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"]=="a2")
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a2")
                            passed += 1
                        end
                    when 7
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 8
                        # strange extra event
                        if !(value["message"]["content"].key?("unmark"))
                            passed += 1
                        end        
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        # error message! Check once it can run
        def cf_cancel_multiple_instance_activity(cf_events)
            passed = 0
            ecid = 0 
            if cf_events.length == 9
                cf_events.each do |key, value|
                    case key
                    when 0
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/split/)
                            passed += 1
                            ecid = value["message"]["content"]["ecid"]
                        end
                    when 1
                        if !(value["message"]["content"].key?("at") && ["a4","a5","a6"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 2
                        if !(value["message"]["content"].key?("at") && ["a4","a5","a6"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 3
                        if !(value["message"]["content"].key?("at") && ["a4","a5","a6"].include?(value["message"]["content"]["at"][0]["position"]))
                            passed += 1
                        end
                    when 4
                        if !(value["message"]["content"].key?("wait") && ["a4","a5","a6"].include?(value["message"]["content"]["wait"][0]["position"]))
                            passed += 1
                        end
                    when 5
                        if !(value["message"]["content"].key?("wait") && ["a4","a5","a6"].include?(value["message"]["content"]["wait"][0]["position"]))
                            passed += 1
                        end
                    when 6
                        if !(value["message"]["content"].key?("wait") && ["a4","a5","a6"].include?(value["message"]["content"]["wait"][0]["position"]))
                            passed += 1
                        end
                    when 7
                        if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/join/ && value["message"]["content"]["ecid"] == ecid)
                            passed += 1
                        end
                    when 8
                        # strange extra event
                        if !(value["message"]["content"].key?("unmark"))
                            passed += 1
                        end        
                    end
                end
                (passed == 0)
            else
                false
            end
        end

        # runs with error, because of dataelements change
        def cf_loop_posttest(cf_events)

        end
        # runs with error, because of dataelements change
        def cf_loop_pretest(cf_events)

        end
    #}}}
    end


    def run_tests_on(testcase_doc)
        ruby_log = run_test_case(testcase_doc, "ruby")
        rust_log = run_test_case(testcase_doc, "rust")


        differences_log_entries = completeness_test(rust_log, ruby_log)
        matches = match_logs(rust_log, ruby_log, differences_log_entries[1], differences_log_entries[2])

        structure_differences_ruby = {}
        structure_differences_rust = {}

        content_differences_ruby = {}
        content_differences_rust = {}

        matches[0].each do |entry, value| 
            if value.instance_of?(Integer)
                dif_structure = structure_test(rust_log[value]["message"], ruby_log[key]["message"])
                structure_differences_ruby << {key => dif_structure[1]}
                structure_differences_rust << {value => dif_structure[0]}
                diff_content = content_test(rust_log[value]["message"], dif_structure[0], ruby_log[key]["message"], dif_structure[1])
                content_differences_ruby << {key => diff_content}
                content_differences_rust << {value => diff_content}
            end
        end

        ruby_cf_events = extract_cf_events(ruby_log)
        rust_cf_events = extract_cf_events(rust_log)

        [differences_log_entries, matches,  structure_differences_ruby, structure_differences_rust, content_differences_ruby, content_differences_rust, ruby_cf_events, rust_cf_events]

    end


    def test_service_call()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_service_call(results[6])
        cf_rust_result = cf_service_call(results[7])

        # TODO communicate to frontend
    end

    def test_service_script_call()
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_service_script_call(results[6])
        cf_rust_result = cf_service_script_call(results[7])

    end

    def test_script_call()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_script_call(results[6])
        cf_rust_result = cf_script_call(results[7])

        # TODO communicate to frontend
    end

    def test_subprocess_call()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_subprocess_call(results[6])
        cf_rust_result = cf_subprocess_call(results[7])

        # TODO communicate to frontend
    end

    # Workflow patterns fully supported by the CPEE start from here

    # Basic Control flow
    def test_sequence()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_sequence(results[6])
        cf_rust_result = cf_sequence(results[7])

        # TODO communicate to frontend
    end

    def test_exclusive_choice_simple_merge()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_exclusive_choice_simple_merge(results[6])
        cf_rust_result = cf_exclusive_choice_simple_merge(results[7])

        # TODO communicate to frontend
    end

    def test_parallel_split_synchronization()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_parallel_split_synchronization(results[6])
        cf_rust_result = cf_parallel_split_synchronization(results[7])

        # TODO communicate to frontend
        
    end

    # Advanced Branching and Synchronization

    def test_multichoice_chained()
         # TODO: setup doc links
         testdoc = ""
         results = run_tests_on(testdoc)
 
         cf_ruby_result = cf_multichoice_chained(results[6])
         cf_rust_result = cf_multichoice_chained(results[7])
 
         # TODO communicate to frontend
    end

    def test_multichoice_parallel()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_multichoice_parallel(results[6])
        cf_rust_result = cf_multichoice_parallel(results[7])

        # TODO communicate to frontend

    end

    def test_cancelling_discriminator()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_cancelling_discriminator(results[6])
        cf_rust_result = cf_cancelling_discriminator(results[7])

        # TODO communicate to frontend

    end

    def test_thread_split_thread_merge()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_thread_split_thread_merge(results[6])
        cf_rust_result = cf_thread_split_thread_merge(results[7])

        # TODO communicate to frontend
    end

    # Multiple Instances

    def test_multiple_instances_with_design_time_knowledge()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_multiple_instances_with_design_time_knowledge(results[6])
        cf_rust_result = cf_multiple_instances_with_design_time_knowledge(results[7])

        # TODO communicate to frontend
    end

    # Impossible to test against one another
    def test_multiple_instances_with_runtime_time_knowledge()
    end

    # Impossible to test against one another
    def test_multiple_instances_without_runtime_time_knowledge()
    end

    def test_cancelling_partial_join_multiple_instances()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_cancelling_partial_join_multiple_instances(results[6])
        cf_rust_result = cf_cancelling_partial_join_multiple_instances(results[7])

        # TODO communicate to frontend
    end

    # State Based

    def test_interleaved_routing()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_interleaved_routing(results[6])
        cf_rust_result = cf_interleaved_routing(results[7])

        # TODO communicate to frontend
    end


    def test_interleaved_parallel_routing()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_interleaved_parallel_routing(results[6])
        cf_rust_result = cf_interleaved_parallel_routing(results[7])

        # TODO communicate to frontend
    end

    def test_critical_section()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_critical_section(results[6])
        cf_rust_result = cf_critical_section(results[7])

        # TODO communicate to frontend
    end

    # Cancellation and Force Completion

    def test_cancel_multiple_instance_activity()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_cancel_multiple_instance_activity(results[6])
        cf_rust_result = cf_cancel_multiple_instance_activity(results[7])

        # TODO communicate to frontend
    end

    # Iterations

    def test_loop_posttest()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_loop_posttest(results[6])
        cf_rust_result = cf_loop_posttest(results[7])

        # TODO communicate to frontend
    end

    def test_loop_pretest()
        # TODO: setup doc links
        testdoc = ""
        results = run_tests_on(testdoc)

        cf_ruby_result = cf_loop_pretest(results[6])
        cf_rust_result = cf_loop_prettest(results[7])

        # TODO communicate to frontend
    end
end

