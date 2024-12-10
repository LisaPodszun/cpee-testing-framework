require_relative 'helpers'
require 'xml/smart'
require 'pathname'
module TestHelpers
    NON_TESTABLE_ENTRIES = ["instance-uuid", "content_at_uuid","content_unmark_uuid","content_after_uuid", "uuid"] #["instance-url","instance","instance-uuid","content_attributes_uuid","content_at_uuid","content_unmark_uuid","content_after_uuid" ,
        #"timestamp", "uuid", "ecid", "content_ecid", "content_activity-uuid"]

    # TODO: find out how to start rust instance
    def run_test_case(start_url, doc_url, data)
        puts 'in run test case'
        instance, uuid, url = post_testset(start_url, doc_url)
        puts 'after post testset'
        puts "Instance #{instance}, UUID: #{uuid}, URL: #{url}"
        data[url] = {}
        data[url][:resource_utilization] = []
        data[url][:end] =  WEEL::Continue.new
        data[url][:log] = {}
        handle_starting(instance, url)

        puts 'before wait'
        puts "URL-ID: #{url}"
        data[url][:end].wait
        puts 'after wait'
        # sort by timestamp from weel
        data[url][:log] = data[url][:log].sort_by{|key, value| key}
        data[url][:log].each_with_index do |entry,i|
            entry[0] = i
        end
        data[url][:log].to_h
    end
    
    def run_tests_on(settings, data, testcase)
        puts "in run tests on"

        engine_1 = settings['instance_1']['process_engine']
        engine_2 = settings['instance_2']['process_engine']
        doc_url_ins_1 = ''
        doc_url_ins_2 = ''


        pn =  Pathname.new(__dir__).parent.parent
        puts pn.join('server/config.json')
        file = File.read(pn.join('server/config.json'))
        config = JSON.parse(file)


        config['tests'].each do |entry|
          if entry['name'] == testcase
            doc_url_ins_1 = entry[settings['instance_1']['execution_handler']]
            doc_url_ins_2 = entry[settings['instance_2']['execution_handler']]
            break
          end
        end
        puts "DOC URL 1: #{doc_url_ins_1}"
        puts "DOC URL 2: #{doc_url_ins_2}"
        ruby_log = run_test_case(engine_1, doc_url_ins_1, data)

        puts "Ruby log"
        p ruby_log
        rust_log = run_test_case(engine_2, doc_url_ins_2, data)

        puts "Rust log"
        p rust_log
        puts "finished running tests"

        differences_log_entries = completeness_test(rust_log, ruby_log)
        matches = match_logs(rust_log, ruby_log, differences_log_entries[1], differences_log_entries[2])

        puts "matched logs"
        puts "can match perfectly? #{!(matches[0].values.include?("no_match") || matches[1].values.include?("no_match"))}"

        structure_differences_ruby = {}
        structure_differences_rust = {}

        content_differences_ruby = {}
        content_differences_rust = {}

        matches[0].each do |key, value|
            if value.instance_of?(Integer)
                dif_structure = structure_test(rust_log[value]["message"], ruby_log[key]["message"])
                structure_differences_ruby.merge!({key => dif_structure[1]})
                structure_differences_rust.merge!({value => dif_structure[0]})
                diff_content = content_test(rust_log[value]["message"], dif_structure[0], ruby_log[key]["message"], dif_structure[1])
                content_differences_ruby.merge!({key => diff_content})
                content_differences_rust.merge!({value => diff_content})
            end
        end

        ruby_cf_events = extract_cf_events(ruby_log)
        rust_cf_events = extract_cf_events(rust_log)

        puts "Equal amounts of cf events? #{(ruby_cf_events.length == rust_cf_events.length)}"
        {"log_instance_1" => ruby_log,"log_instance_2" => rust_log, 'differences_log_entries' => differences_log_entries, "matches" => matches,  'structure_differences' => [structure_differences_ruby, structure_differences_rust], 'content_differences' => [content_differences_ruby, content_differences_rust], 'cf_ins_1' => ruby_cf_events, 'cf_ins_2' => rust_cf_events}
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
            elsif value.class == Array
                diff << hash_structure_test(path, value[0], hash_2[key][0])
            end
            path.pop
        end
        diff.flatten
    end

    def content_test(rust_log_entry, dif_rust_to_ruby, ruby_log_entry, dif_ruby_to_rust)
        # save all common keys and if they hold the same or different values
        puts "Keys to not include"
        p dif_ruby_to_rust
        puts "Keys to not include"
        p dif_rust_to_ruby
        dif_content_keys = hash_content_test([], rust_log_entry, ruby_log_entry, dif_rust_to_ruby, dif_ruby_to_rust)
    end

    def hash_content_test(path, hash_1, hash_2, dif_rust_to_ruby, dif_ruby_to_rust)
        diff = []
        # test hash_1 > hash_2
        hash_1.each do |key, value|
            path << key
            if !(NON_TESTABLE_ENTRIES.include?(path.join("_")) || dif_rust_to_ruby.include?(path.join("_")) || dif_ruby_to_rust.include?(path.join("_")) || value.class == Hash || value.class == Array)
                if (value != hash_2[key])
                    diff << path.join("_")
                end
            elsif value.class == Hash
                diff << (hash_content_test(path, value, hash_2[key], dif_rust_to_ruby, dif_ruby_to_rust))
            elsif value.class == Array
                p value[0]
                p hash_2[key]
                diff << (hash_content_test(path, value[0], hash_2[key][0], dif_rust_to_ruby, dif_ruby_to_rust))
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
            channel = value["channel"]
            if !events_rust.key?(channel)
                events_rust.store(channel, 0)
            end
            events_rust[channel] += 1
        end
        # store {event_type: amount}
        ruby_log.each do |key, value|
            channel = value["channel"]
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
            channel = entry["channel"]
            if (["position/change", "gateway/decide", "gateway/join", "gateway/split"].include?(channel) && entry["message"]["instance-name"] != "subprocess")
                cf_events.merge!({index => entry})
                index +=1
            end
        end
        cf_events
    end

    def events_match?(ruby_log_entry, rust_log_entry)
        channel = ruby_log_entry["channel"]
        case channel
                when "state/change"
                    rust_log_entry["message"]["content"]["state"] == ruby_log_entry["message"]["content"]["state"]
                when "position/change"
                    content_keys = ruby_log_entry["message"]["content"].keys
                    atFlag = true
                    afterFlag = true
                    unmarkFlag = true
                    waitFlag = true
                    # For now just check the first in each position/change (unmark, at, after) as the test only include those cases
                    if content_keys.include?("at")
                        if rust_log_entry["message"]["content"].keys.include?("at")
                            unless (ruby_log_entry["message"]["content"]["at"].length() == 1 && rust_log_entry["message"]["content"]["at"].length() == 1)
                                STDERR.puts "position change at unexpectedly contained more than 1 entry for the test cases!"
                            end
                            atFlag = ruby_log_entry["message"]["content"]["at"][0]["position"] == rust_log_entry["message"]["content"]["at"][0]["position"]
                        else
                            atFlag = false
                        end
                    end
                    if content_keys.include?("after")
                        if rust_log_entry["message"]["content"].keys.include?("after")
                            unless (ruby_log_entry["message"]["content"]["after"].length() == 1 && rust_log_entry["message"]["content"]["after"].length() == 1)
                                STDERR.puts "position change after unexpectedly contained more than 1 entry for the test cases!"
                            end
                            afterFlag = ruby_log_entry["message"]["content"]["after"][0]["position"] == rust_log_entry["message"]["content"]["after"][0]["position"]
                        else
                            afterFlag = false
                        end
                    end
                    if content_keys.include?("unmark")
                        if rust_log_entry["message"]["content"].keys.include?("unmark")
                            unless (ruby_log_entry["message"]["content"]["unmark"].length() == 1 && rust_log_entry["message"]["content"]["unmark"].length() == 1)
                                STDERR.puts "position change unmark unexpectedly contained more than 1 entry for the test cases!"
                            end
                            unmarkFlag = ruby_log_entry["message"]["content"]["unmark"][0]["position"] == rust_log_entry["message"]["content"]["unmark"][0]["position"]
                        else
                            unmarkFlag = false
                        end
                    end
                    if content_keys.include?("wait")
                        if rust_log_entry["message"]["content"].keys.include?("wait")
                            unless (ruby_log_entry["message"]["content"]["wait"].length() == 1 && rust_log_entry["message"]["content"]["wait"].length() == 1)
                                STDERR.puts "position change unmark unexpectedly contained more than 1 entry for the test cases!"
                            end
                            waitFlag = ruby_log_entry["message"]["content"]["wait"][0]["position"] == rust_log_entry["message"]["content"]["wait"][0]["position"]
                        else
                            waitFlag = false
                        end
                    end
                    return atFlag && afterFlag && unmarkFlag && waitFlag
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
        matched_entries_rust = Set[]
        while (ruby_index < ruby_log.length)
            ruby_event_type = ruby_log[ruby_index]["channel"]
            rust_event_type = rust_log[rust_index]["channel"]
            if missing_events_rust.include?(ruby_event_type)
                # Rust log does not contain that event type, thus skip it
                ruby_log_tags = ruby_log_tags.merge({ruby_index => "only_ins_1"})
                ruby_index += 1
                rust_index = 0
            elsif rust_event_type == ruby_event_type && (!matched_entries_rust.include? rust_index) && events_match?(rust_log[rust_index],ruby_log[ruby_index])
                    matched_entries_rust.add(rust_index)
                    ruby_log_tags = ruby_log_tags.merge({ruby_index => rust_index})
                    rust_log_tags = rust_log_tags.merge({rust_index => ruby_index})
                    ruby_index += 1
                    rust_index = 0
            else
                rust_index += 1
                if (rust_index >= rust_log.length)
                    p "could not find match for #{ruby_event_type}, Content ins 1: #{ruby_log[ruby_index]}"
                    ruby_log_tags = ruby_log_tags.merge({ruby_index => "no_match"})
                    ruby_index += 1
                    rust_index = 0
                end
            end
        end
        rust_index = 0
        while (rust_index < rust_log.length)
            event_type = rust_log[rust_index]["channel"]
            if missing_events_ruby.include?(event_type)
                rust_log_tags = rust_log_tags.merge({rust_index => "only_ins_2"})
                rust_index += 1
            elsif rust_log_tags.keys.include?(rust_index)
                rust_index += 1
            else
                rust_log_tags = rust_log_tags.merge({rust_index => "no_match"})
                p "could not find match for #{event_type}, Content ins 2: #{rust_log[rust_index]}"
                rust_index += 1
            end
        end
        # (possibly) wrong match for testing
        #ruby_log_tags.merge!({1 => 3})
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                        passed += 1
                    end
                when 2
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a1")
                        passed += 1
                    end
                end
            end
            (passed == 0)
        else
            puts "not enough cf events! Expected 3 but got #{cf_events.length}"
            p cf_events
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                        passed += 1
                    end
                when 2
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a1")
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                        passed += 1
                    end
                when 2
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a1")
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                        passed += 1
                    end
                when 2
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a1")
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a2")
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                        passed += 1
                    end
                when 6
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

    def cf_multi_choice_chained(cf_events)
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                        passed += 1
                    end
                when 10
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

    # TODO : fix this test, see if it can execute
    def cf_multi_choice_parallel(cf_events)

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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                        passed += 1
                    end
                when 10
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a1")
                        passed += 1
                    end
                when 4
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a1")
                        passed += 1
                    end
                when 5
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a2")
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
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                        passed += 1
                    end
                when 9
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                        passed += 1
                    end
                when 10
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

    # no real sequence of events, everything runs random, therefore bare-minimum test
    def cf_multiple_instances_with_design_time_knowledge(cf_events)
        if cf_events.length == 22
            true
        else
            false
        end
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
        # Count extra event as error
        if cf_events.length == 21
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
                
                #when 21
                    # strange extra position/change event sent
                 #   //if !(value["message"]["content"].key?("unmark"))
                 #       passed += 1
                #    end
                    
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
               # when 10
                    # strange extra event
                #    if !(value["message"]["content"].key?("unmark"))
                #        passed += 1
                #    end
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
        if cf_events.length == 8
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
                #when 8
                    # strange extra event
                #    if !(value["message"]["content"].key?("unmark"))
                #        passed += 1
                #    end
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
                #when 8
                    # strange extra event
                #    if !(value["message"]["content"].key?("unmark"))
                #        passed += 1
                #    end
                end
            end
            (passed == 0)
        else
            false
        end
    end

    # runs with error, because of dataelements change
    def cf_loop_posttest(cf_events)
        passed = 0
        ecid = 0
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a2")
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
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                        passed += 1
                    end
                when 6
                    if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/)
                        passed += 1
                        ecid == value["message"]["content"]["ecid"]
                    end
                when 7
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a3")
                        passed += 1
                    end
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
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
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                        passed += 1
                    end
                when 10
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                        passed += 1
                    end
                when 11
                    if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/ && value["message"]["content"]["ecid"] == ecid)
                        passed += 1
                    end
                when 7
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a3")
                        passed += 1
                    end
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
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
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                        passed += 1
                    end
                when 10
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                        passed += 1
                    end
                when 11
                    if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/ && value["message"]["content"]["ecid"] == ecid)
                        passed += 1
                    end
                when 12
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a3")
                        passed += 1
                    end
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
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
    def cf_loop_pretest(cf_events)
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
                    if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/)
                        passed += 1
                        ecid = value["message"]["content"]["ecid"]
                    end
                when 3
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a1")
                        passed += 1
                    end
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
                        passed += 1
                    end
                when 4
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a2")
                        passed += 1
                    end
                when 5
                    if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/ && value["message"]["content"]["ecid"] == ecid)
                        passed += 1
                    end
                when 6
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a2")
                        passed += 1
                    end
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
                        passed += 1
                    end
                when 7
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a2")
                        passed += 1
                    end
                when 8
                    if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/ && value["message"]["content"]["ecid"] == ecid)
                        passed += 1
                    end
                when 9
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a2")
                        passed += 1
                    end
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a2")
                        passed += 1
                    end
                when 10
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a2")
                        passed += 1
                    end
                when 11
                    if !(value["channel"] =~ /event:[0-9][0-9]:gateway\/decide/ && value["message"]["content"]["ecid"] == ecid)
                        passed += 1
                    end
                when 12
                    if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["unmark"][0]["position"] == "a2")
                        passed += 1
                    end
                    if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"][0]["position"] == "a3")
                        passed += 1
                    end
                when 10
                    if !(value["message"]["content"].key?("after") && value["message"]["content"]["after"][0]["position"] == "a3")
                        passed += 1
                    end
                when 11
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
    #}}}


end
