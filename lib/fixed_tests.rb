require_relative 'helpers'



module FixedTests
    
    module TestHelpers
        const @@non_testable_entries = ["instance-url","instance","instance-uuid","content_attributes_uuid","content_at_uuid",
         "timestamp", "uuid", "ecid", "content_ecid", "content_activity-uuid", "content_unmark_uuid"]
        
        def run_test_case(doc, weel)
            instance, uuid = post_testset(doc)
            wait = Queue.new
            [connection, event_log] = subscribe_all(instance, wait)
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
                    diff << hash_test(path, value, hash_2[key])
                end
                path.pop
            end
            diff
        end
        
        def content_test(rust_log_entry, dif_rust_to_ruby, ruby_log_entry, dif_ruby_to_rust)
            # save all common keys and if they hold the same or different values
            dif_content_keys = hash_content_test([], rust_log_entry, ruby_log_entry, dif_rust_to_ruby, dif_ruby_to_rust)
        end
        
        def hash_content_test(path, hash_1, hash_2, dif_rust_to_ruby, dif_ruby_to_rust)
            diff = {}
            # test hash_1 > hash_2 
            hash_1.each do |key, value|
                path << key
                if !(@@non_testable_entries.include?(path.join("_")) || dif_rust_to_ruby.include?(path.join("_")) || dif_ruby_to_rust.include?(path.join("_")) || value.class == Hash)
                    diff << {path.join("_") => (value == hash_2[key])}
                elsif value.class == Hash
                    diff << hash_content_test(path, value, hash_2[key], dif_rust_to_ruby, dif_ruby_to_rust)
                end
                path.pop
            end
            diff
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
                if !events_rust.key?(value["channel"])
                    events_rust.store(value["channel"], 0)
                end
                events_rust[value["channel"]] += 1
            end
            # store {event_type: amount}
            ruby_log.each do |key, value|
                if !events_ruby.key?(value["channel"])
                    events_ruby.store(value["channel"], 0)
                end
                events_ruby[value["channel"]] += 1
            end
            # calculate dif ruby - rust for each event
            events_ruby.each do |key, value|
                if events_rust.key?(key)
                    events_dif << {key: (value - events_rust[key])}
                else
                    events_dif << {key: value}
                    missing_events_rust << key
                end
            end
            # check for missing events from other event log
            events_rust.each do |key, value|
                if !events_ruby.key?(key)
                    events_dif << {key: -value}
                    missing_events_ruby << key
                end
            end
            [events_dif, missing_events_ruby, missing_events_rust]
        end

        def extract_cf_events(log)
            cf_events = {}
            index = 0
            log.values.each do |entry|
                if ["event:00:position/change", "event:00:gateway/decide", "event:00:gateway/join", "event:00:gateway/split"].include?(entry["channel"])
                    cf_events << {index => entry}
                    index +=1
                end
            end
            cf_events 
        end

        def events_match?(ruby_log_entry, rust_log_entry)

            event_type = ruby_log_entry["channel"]
            case event_type
            when "event:00:position/change"
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
            when "event:00:gateway/decide"
                rust_log_entry["message"]["content"]["code"] == ruby_log_entry["message"]["content"]["code"]

            when "event:00:gateway/join"
                rust_log_entry["message"]["content"]["branches"] == ruby_log_entry["message"]["content"]["branches"]
                
            when "event:00:gateway/split"
                rust_log_entry["message"]["name"] == ruby_log_entry["message"]["name"]

            when "event:00:dataelements/change"
                dataelements = (rust_log_entry["message"]["content"]["changed"] == ruby_log_entry["message"]["content"]["changed"])
                values = (rust_log_entry["message"]["content"]["values"] == ruby_log_entry["message"]["content"]["values"])
                dataelements && values

            when "event:00:activity/calling"
                rust_log_entry["message"]["content"]["activity"] == ruby_log_entry["message"]["content"]["activity"] 

            when "event:00:activity/manipulating"
                rust_log_entry["message"]["content"]["activity"] == ruby_log_entry["message"]["content"]["activity"] 

            when "event:00:activity/done"
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
            while (ruby_index < ruby_log.length)
                event_type = ruby_log[ruby_index]["channel"]
                if missing_events_rust.include?(event_type)
                    ruby_log_tags << {ruby_index => "only_ruby"}
                    ruby_index += 1
                elsif rust_log[rust_index]["channel"] == event_type
                    if events_match?(rust_log[rust_index],ruby_log[ruby_index])
                        ruby_log_tags << {ruby_index => rust_index}
                        rust_log_tags << {rust_index => ruby_index}
                        ruby_index += 1
                        rust_index += 1
                        after_last_rust_match = rust_index
                    else
                        rust_index += 1
                        if (rust_index == rust_log.length)
                            ruby_log_tags << {ruby_index => "no_match"}
                            rust_index = after_last_rust_match
                            ruby_index += 1
                        end
                    end
                end
            end
            rust_index = 0
            while (rust_index < rust_log.length)
                event_type = rust_log[rust_index]["channel"]
                if missing_events_ruby.include?(event_type)
                    rust_log_tags << {rust_index => "only_rust"}
                    rust_index += 1
                elsif rust_log_tags.keys.include?(rust_index)
                    rust_index += 1
                else
                    rust_log_tags << {rust_index => "no_match"}
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
                        if !(value["message"]["content"].key?("at") && value["message"]["content"]["at"] == "a1")
                            passed += 1
                    when 1
                        if !(value["message"]["content"].key?("after") && value["message"]["content"]["at"] == "a1")
                            passed += 1
                    when 2
                        if !(value["message"]["content"].key?("unmark") && value["message"]["content"]["at"] == "a1")
                            passed += 1
                    end
                end
                (passed == 0)
            else
                # TODO: no control flow test possible, missing events
                false
            end
        end

        def cf_service_script_call()
        end

        def cf_script_call()
        end

        def cf_subprocess_call()
        end

        def cf_sequence()
        end

        def cf_exclusive_choice_simple_merge()
        end

        def cf_parallel_split_synchronization()
        end

        def cf_multichoice_chained()
        end

        def cf_multichoice_parallel()
        end

        def cf_cancelling_discriminator()
        end

        def cf_thread_split_thread_merge()
        end

        def cf_multiple_instances_with_design_time_knowledge()
        end

        def cf_multiple_instances_with_runtime_time_knowledge()
        end

        def cf_multiple_instances_without_runtime_time_knowledge()
        end

        def cf_cancelling_partial_join_multiple_instances()
        end

        def cf_interleaved_routing()
        end

        def cf_interleaved_parallel_routing()
        end

        def cf_critical_section()
        end

        def cf_cancel_multiple_instance_activity()
        end

        def cf_loop_posttest()
        end

        def cf_loop_pretest()
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

