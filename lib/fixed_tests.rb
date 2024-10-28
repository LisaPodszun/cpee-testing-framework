require_relative 'helpers'



module FixedTests
    
    module TestHelpers
    
        def run_test_case(doc, weel)
            instance, uuid = post_testset(doc)
            EM.defer do
               event_log = subscribe_all(instance)
            end
            EM.defer do
               handle_starting(instance)
            end
            event_log
        end

        def hash_test(master_key, hash_1, hash_2)
            
            # test hash_1 > hash_2 
            hash_1.each do |key, value|
                if !hash_2.key?(key)
                    return master_key + "_" + key
                elsif value.class == Hash
                    new_key = master_key + "_" + key
                    return hash_test(new_key, value, hash_2[key])
                end
            end
        end
        def structure_test(rust_log_entry, ruby_log_entry)
            # holds all keys ruby > rust
            dif_ruby_to_rust = []
            # holds all keys ruby < rust
            dif_rust_to_ruby = []

            dif_ruby_to_rust << hash_test("", ruby_log_entry, rust_log_entry)

            dif_rust_to_ruby << hash_test("", rust_log_entry, ruby_log_entry)

            [dif_rust_to_ruby, dif_ruby_to_rust]
        end

        def content_test(rust_log_entry, ruby_log_entry)
            const non_testable_entries = ["instance-url","instance", "timestamp", "content_attributes_uuid",
             "instance-uuid", "content_uuid", "content-activity-uuid", "content_ecid", ""]

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
                else
                    events_rust[value["channel"]] += 1
                end
            end
            # store {event_type: amount}
            ruby_log.each do |key, value|
                if !events_ruby.key?(value["channel"])
                    events_ruby.store(value["channel"], 0)
                else
                    events_ruby[value["channel"]] += 1
                end
            end
            # calculate dif ruby - rust for each event
            events_ruby.each do |key, value|
                if events_rust.key?(key)
                    events_dif << {key: (value - events_rust[key])}
                else
                    events_dif << {key: 1}
                    missing_events_rust << key
                end
            end
            # check for missing events from other event log
            events_rust.each do |key, value|
                if !events_ruby.key?(key)
                    events_dif << {key: -1}
                    missing_events_ruby << key
                end
            end
            [events_dif, missing_events_ruby, missing_events_rust]
        end
    end


    def test_service_call()
        testcase_doc = ""
        ruby_log = run_test_case(testcase_doc, "ruby")
        rust_log = run_test_case(testcase_doc, "rust")






    end

    def test_service_script_call()
    end

    def test_script_call()
    end

    def test_subprocess_call()
    end

    # Workflow patterns fully supported by the CPEE start from here

    # Basic Control flow
    def test_sequence()
    end

    def test_exclusive_choice_simple_merge()
    end

    def test_parallel_split_synchronization()
    end

    # Advanced Branching and Synchronization

    def test_multichoice_chained()
    end

    def test_multichoice_parallel()
    end

    def test_cancelling_discriminator()
    end

    def test_thread_split_thread_merge()
    end

    # Multiple Instances

    def test_multiple_instances_with_design_time_knowledge()
    end

    def test_multiple_instances_with_runtime_time_knowledge()
    end

    def test_multiple_instances_without_runtime_time_knowledge()
    end

    def test_cancelling_partial_join_multiple_instances()
    end

    # State Based

    def test_interleaved_routing()
    end

    def test_interleaved_parallel_routing()
    end

    def test_critical_section()
    end

    # Cancellation and Force Completion

    def test_cancel_multiple_instance_activity()
    end

    # Iterations

    def test_loop_posttest()
    end

    def test_loop_pretest()
    end
end

