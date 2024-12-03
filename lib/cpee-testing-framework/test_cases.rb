require 'json'
require_relative 'fixed_tests'

module TestCases
  include TestHelpers

  def service_call(data, testinstance, settings)

    results = run_tests_on(settings, data, 'service_call')

    results['cf_ins_1'] = cf_service_call(results['cf_ins_1'])
    results['cf_ins_2'] = cf_service_call(results['cf_ins_2'])

    testinstance[:results][:service_call] = results

    p "ran all tests successfully"
  end

  def service_script_call(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'service_script_call')

    results['cf_ins_1'] = cf_service_script_call(results['cf_ins_1'])
    results['cf_ins_2'] = cf_service_script_call(results['cf_ins_2'])

    testinstance[:results][:service_script_call] = results
  end

  def script_call(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'script_call')

    results['cf_ins_1'] = cf_script_call(results['cf_ins_1'])
    results['cf_ins_2'] = cf_script_call(results['cf_ins_2'])

    testinstance[:results][:script_call] = results
  end

  def subprocess_call(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'subprocess_call')

    results['cf_ins_1'] = cf_subprocess_call(results['cf_ins_1'])
    results['cf_ins_2'] = cf_subprocess_call(results['cf_ins_2'])

    testinstance[:results][:subprocess_call] = results
  end

  # Workflow patterns fully supported by the CPEE start from here

  # Basic Control flow
  def sequence(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'sequence')

    results['cf_ins_1'] = cf_sequence(results['cf_ins_1'])
    results['cf_ins_2'] = cf_sequence(results['cf_ins_2'])

    testinstance[:results][:sequence] = results
  end

  def exclusive_choice_simple_merge(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'exclusive_choice_simple_merge')

    results['cf_ins_1'] = cf_exclusive_choice_simple_merge(results['cf_ins_1'])
    results['cf_ins_2'] = cf_exclusive_choice_simple_merge(results['cf_ins_2'])

    testinstance[:results][:exclusive_choice_simple_merge] = results
  end

  def parallel_split_and_synchronization(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'parallel_split_and_synchronization')

    results['cf_ins_1'] = cf_parallel_split_synchronization(results['cf_ins_1'])
    results['cf_ins_2'] = cf_parallel_split_synchronization(results['cf_ins_2'])

    testinstance[:results][:parallel_split_synchronization] = results

  end

  # Advanced Branching and Synchronization

  def multi_choice_chained(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'multi_choice_chained')

    results['cf_ins_1'] = cf_multi_choice_chained(results['cf_ins_1'])
    results['cf_ins_2'] = cf_multi_choice_chained(results['cf_ins_2'])

    testinstance[:results][:multi_choice_chained] = results
  end

  def multi_choice_parallel(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'multi_choice_parallel')

    results['cf_ins_1'] = cf_multi_choice_parallel(results['cf_ins_1'])
    results['cf_ins_2'] = cf_multi_choice_parallel(results['cf_ins_2'])

    testinstance[:results][:multi_choice_parallel] = results

  end

  def cancelling_discriminator(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'cancelling_discriminator')

    results['cf_ins_1'] = cf_cancelling_discriminator(results['cf_ins_1'])
    results['cf_ins_2'] = cf_cancelling_discriminator(results['cf_ins_2'])

    testinstance[:results][:cancelling_discriminator] = results

  end

  def thread_split_thread_merge(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'thread_split_thread_merge')

    results['cf_ins_1'] = cf_thread_split_thread_merge(results['cf_ins_1'])
    results['cf_ins_2'] = cf_thread_split_thread_merge(results['cf_ins_2'])

    testinstance[:results][:thread_split_thread_merge] = results
  end

  # Multiple Instances

  def multiple_instances_with_design_time_knowledge(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'multiple_instances_with_design_time_knowledge')

    results['cf_ins_1'] = cf_multiple_instances_with_design_time_knowledge(results['cf_ins_1'])
    results['cf_ins_2'] = cf_multiple_instances_with_design_time_knowledge(results['cf_ins_2'])

    testinstance[:results][:multiple_instances_with_design_time_knowledge] = results
  end

  # Impossible to test against one another
  def multiple_instances_with_runtime_time_knowledge(data, testinstance, settings)
  end

  # Impossible to test against one another
  def multiple_instances_without_runtime_time_knowledge(data, testinstance, settings)
  end

  def cancelling_partial_join_multiple_instances(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'cancelling_partial_join_multiple_instances')

    results['cf_ins_1'] = cf_cancelling_partial_join_multiple_instances(results['cf_ins_1'])
    results['cf_ins_2'] = cf_cancelling_partial_join_multiple_instances(results['cf_ins_2'])

    testinstance[:results][:cancelling_partial_join_multiple_instances] = results
  end

  # State Based

  def interleaved_routing(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'interleaved_routing')

    results['cf_ins_1'] = cf_interleaved_routing(results['cf_ins_1'])
    results['cf_ins_2'] = cf_interleaved_routing(results['cf_ins_2'])

    testinstance[:results][:interleaved_routing] = results
  end


  def interleaved_parallel_routing(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'interleaved_parallel_routing')

    results['cf_ins_1'] = cf_interleaved_parallel_routing(results['cf_ins_1'])
    results['cf_ins_2'] = cf_interleaved_parallel_routing(results['cf_ins_2'])

    testinstance[:results][:interleaved_parallel_routing] = results
  end

  def critical_section(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'critical_section')

    results['cf_ins_1'] = cf_critical_section(results['cf_ins_1'])
    results['cf_ins_2'] = cf_critical_section(results['cf_ins_2'])

    testinstance[:results][:critical_section] = results
  end

  # Cancellation and Force Completion

  def cancel_multiple_instance_activity(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'cancel_multiple_instance_activity')

    results['cf_ins_1'] = cf_cancel_multiple_instance_activity(results['cf_ins_1'])
    results['cf_ins_2'] = cf_cancel_multiple_instance_activity(results['cf_ins_2'])

    testinstance[:results][:cancel_multiple_instance_activity] = results
  end

  # Iterations

  def loop_posttest(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'loop_posttest')

    results['cf_ins_1'] = cf_loop_posttest(results['cf_ins_1'])
    results['cf_ins_2'] = cf_loop_posttest(results['cf_ins_2'])

    testinstance[:results][:loop_posttest] = results
  end

  def loop_pretest(data, testinstance, settings)
    
    results = run_tests_on(settings, data, 'loop_pretest')

    results['cf_ins_1'] = cf_loop_pretest(results['cf_ins_1'])
    results['cf_ins_2'] = cf_loop_pretest(results['cf_ins_2'])

    testinstance[:results][:loop_pretest] = results
  end
end
