require_relative 'helpers'



module FixedTests
    
    module TestHelpers
    
        def run_test_case(doc)
            instance, uuid = post_testset(doc)
            EM.defer do
                handle_waiting(instance,uuid,behavior,selfurl,cblist)
                handle_starting(instance)
            end
            EM.defer do
                subscribe_all(instance)
            end
        end

        def structure_test(logtype, log)
            result = {}
            case logtype
            when "position\change"
                result = {
                    "cpee"              => log.key?('cpee'),
                    "instance-url"      => log.key?('instance-url'),
                    "instance"          => log.key?('instance'),
                    "topic"             => log.key?('instance'),
                    "type"              => log.key?('topic'),
                    "name"              => log.key?('name'),
                    "timestamp"         => log.key?('timestamp'),
                    "content"           => log.key?('content'),                   
                    "instance-uuid"     => log.key?('instance-uuid'),
                    "instance-name"     => log.key?('instance-name')
                }
                if log.key?("content")
                    result["after|unmark"]     => (log['content'].key?('after') || log['content'].key?('unmark'))
                    result["attributes"]       => log["content"].key?('attributes') 
                    if log['content'].key?('after')
                        result["after_position"] => log["content"]["after"].key?("position")
                        result["after_uuid"]     => log["content"]["after"].key?("uuid")
                    elsif log['content'].key?('unmark')
                        result["unmark_position"] => log["content"]["unmark"].key?("position")
                        result["unmark_uuid"]     => log["content"]["unmark"].key?("uuid")
                    end
                    if log["content"].key?("attributes")
                        result["attributes_uuid"]      => log["content"]['attributes'].key?('uuid')
                        result["attributes_info"]      => log["content"]["attributes"].key?("info")
                        result["attributes_modeltype"] => log["content"]["attributes"].key?("modeltype")
                        result["attributes_theme"]     => log["content"]["attributes"].key?("theme")
                    end                  
                end
                result
            when "activity\calling"
                result = {
                    "cpee"              => log.key?('cpee'),
                    "instance-url"      => log.key?('instance-url'),
                    "instance"          => log.key?('instance'),
                    "topic"             => log.key?('instance'),
                    "type"              => log.key?('topic'),
                    "name"              => log.key?('name'),
                    "timestamp"         => log.key?('timestamp'),
                    "content"           => log.key?('content'),
                    "instance-uuid"     => log.key?('instance-uuid'),
                    "instance-name"     => log.key?('instance-name')
                }
                if log.key?("content")
                    result['ecid']                  => log['content'].key?('ecid')
                    result['activity-uuid']         => log["content"].key?('activity-uuid')
                    result['label']                 => log['content'].key?('label')
                    result['activity']              => log['content'].key?('activity')
                    result['passthrough']           => log['content'].key?('passthrough')
                    result['endpoint']              => log['content'].key?('endpoint')
                    result['parameters']            => log['content'].key?('parameters')
                    result['annotations']           => log["content"].key?('annotations')
                    result['attributes']            => log['content'].key?('attributes')
                    if log['content'].key?('parameters')
                        result["parameters_label"]      => log["content"]["parameters"].key?("label")
                        result["parameters_method"]     => log["content"]["parameters"].key?("method")
                        result["parameters_arguments"]  => log["content"]["parameters"].key?("arguments")
                    if log['content'].key?('annotations')
                        result["annotations_generic"]                       => log["content"]["annotations"].key?("_generic")
                        result["annotations_timing"]                        => log["content"]["annotations"].key?("_timing")
                        if log["content"]["annotations"].key?("_timing")
                            result["annotations_timing_timing_weight"]      => log["content"]["annotations"]['_timing'].key?('_timing_weight')
                            result["annotations_timing_timing_avg"]         => log["content"]["annotations"]['_timing'].key?('_timing_avg')
                            result["annotations_timing_explanations"]       => log["content"]["annotations"]['_timing'].key?('explanations')
                        end
                        result["annotations_shifting"]                      => log["content"]["annotations"].key?("_shifting")
                        if log["content"]["annotations"].key?("_shifting")
                            result["annotations_shifting_shifting_type"]    => log["content"]["annotations"]["_shifting"].key?("_shifting_type")
                        end
                        result["annotations_context_data_analysis"]         => log["content"]["annotations"].key?("_context_data_analysis")
                        if log["content"]["annotations"].key?("_context_data_analysis")
                            result["annotations_context_data_analysis_probes"]  => log["content"]["annotations"]["_context_data_analysis"].key?("probes")
                            result["annotations_context_data_analysis_ips"]     => log["content"]["annotations"]["_context_data_analysis"].key?("ips")
                        end
                        result["annotations_report"]                        => log["content"]["annotations"].key?("report")
                        if log["content"]["annotations"].key?("report")
                            result["annotations_report_url"]                => log["content"]["annotations"]["report"].key?('url')
                        end
                        result["annotations_notes"]                         => log["content"]["annotations"].key?("_notes")
                        if log["content"]["annotations"].key?("_notes")
                            result["annotations_notes_notes_general"]       => log["content"]["annotations"]["_notes"]("_notes_general")
                        end
                    end
                    if log["content"].key?("attributes")
                        result["uuid"]      => log["content"]['attributes'].key?('uuid')
                        result["info"]      => log["content"]["attributes"].key?("info")
                        result["modeltype"] => log["content"]["attributes"].key?("modeltype")
                        result["theme"]     => log["content"]["attributes"].key?("theme")
                    end                  
                end
                result
            when "activity\content"
                # TODO: find out when this eventlog happens
            when "activity\receiving"
                result = {
                    "cpee"              => log.key?('cpee'),
                    "instance-url"      => log.key?('instance-url'),
                    "instance"          => log.key?('instance'),
                    "topic"             => log.key?('instance'),
                    "type"              => log.key?('topic'),
                    "name"              => log.key?('name'),
                    "timestamp"         => log.key?('timestamp'),
                    "content"           => log.key?('content'),
                    "instance-uuid"     => log.key?('instance-uuid'),
                    "instance-name"     => log.key?('instance-name')
                }
                if log.key?("content")
                    result['ecid']                  => log['content'].key?('ecid')
                    result['activity-uuid']         => log["content"].key?('activity-uuid')
                    result['label']                 => log['content'].key?('label')
                    result['activity']              => log['content'].key?('activity')
                    result['passthrough']           => log['content'].key?('passthrough')
                    result['endpoint']              => log['content'].key?('endpoint')
                    result['parameters']            => log['content'].key?('parameters')
                    result['annotations']           => log["content"].key?('annotations')
                    result['attributes']            => log['content'].key?('attributes')
                    if log['content'].key?('received')
                        result["received_name"]             => log["content"]["received"].key?("name")
                        result["received_mimetype"]         => log["content"]["received"].key?("mimetype")
                        result["received_data"]             => log["content"]["received"].key?("data")
                    if log['content'].key?('annotations')
                        result["annotations_generic"]                       => log["content"]["annotations"].key?("_generic")
                        result["annotations_timing"]                        => log["content"]["annotations"].key?("_timing")
                        if log["content"]["annotations"].key?("_timing")
                            result["annotations_timing_timing_weight"]      => log["content"]["annotations"]['_timing'].key?('_timing_weight')
                            result["annotations_timing_timing_avg"]         => log["content"]["annotations"]['_timing'].key?('_timing_avg')
                            result["annotations_timing_explanations"]       => log["content"]["annotations"]['_timing'].key?('explanations')
                        end
                        result["annotations_shifting"]                      => log["content"]["annotations"].key?("_shifting")
                        if log["content"]["annotations"].key?("_shifting")
                            result["annotations_shifting_shifting_type"]    => log["content"]["annotations"]["_shifting"].key?("_shifting_type")
                        end
                        result["annotations_context_data_analysis"]         => log["content"]["annotations"].key?("_context_data_analysis")
                        if log["content"]["annotations"].key?("_context_data_analysis")
                            result["annotations_context_data_analysis_probes"]  => log["content"]["annotations"]["_context_data_analysis"].key?("probes")
                            result["annotations_context_data_analysis_ips"]     => log["content"]["annotations"]["_context_data_analysis"].key?("ips")
                        end
                        result["annotations_report"]                        => log["content"]["annotations"].key?("report")
                        if log["content"]["annotations"].key?("report")
                            result["annotations_report_url"]                => log["content"]["annotations"]["report"].key?('url')
                        end
                        result["annotations_notes"]                         => log["content"]["annotations"].key?("_notes")
                        if log["content"]["annotations"].key?("_notes")
                            result["annotations_notes_notes_general"]       => log["content"]["annotations"]["_notes"]("_notes_general")
                        end
                    end
                    if log["content"].key?("attributes")
                        result["uuid"]      => log["content"]['attributes'].key?('uuid')
                        result["info"]      => log["content"]["attributes"].key?("info")
                        result["modeltype"] => log["content"]["attributes"].key?("modeltype")
                        result["theme"]     => log["content"]["attributes"].key?("theme")
                    end                  
                end
                result
            when "activity\manipulating"

            when "activity\done"
                
            when "dataelements\change"
            end

        end

    
    
    end





    def test_service_call()
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

