require 'json'
require_relative 'fixed_tests'

module TestCases
  include TestHelpers
  START =  "https://cpee.org/flow/start/url/"

  def service_call(data, testinstance, settings)

    results = run_tests_on(settings, data)

    cf_ruby_result = cf_service_call(results['cf_ins_1'])
    cf_rust_result = cf_service_call(results['cf_ins_2'])

    testinstance[:service_call][:results] = results

    puts "Passed control flow tests?"
    puts cf_ruby_result
    puts "Passed control flow tests a second time?"
    puts cf_rust_result

    p "ran all tests successfully"
    # TODO communicate to frontend
  end

  def service_script_call()
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_service_script_call(results[6])
    cf_rust_result = cf_service_script_call(results[7])

  end

  def script_call()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_script_call(results[6])
    cf_rust_result = cf_script_call(results[7])

    # TODO communicate to frontend
  end

  def subprocess_call()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_subprocess_call(results[6])
    cf_rust_result = cf_subprocess_call(results[7])

    # TODO communicate to frontend
  end

  # Workflow patterns fully supported by the CPEE start from here

  # Basic Control flow
  def sequence()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_sequence(results[6])
    cf_rust_result = cf_sequence(results[7])

    # TODO communicate to frontend
  end

  def exclusive_choice_simple_merge()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_exclusive_choice_simple_merge(results[6])
    cf_rust_result = cf_exclusive_choice_simple_merge(results[7])

    # TODO communicate to frontend
  end

  def parallel_split_synchronization()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_parallel_split_synchronization(results[6])
    cf_rust_result = cf_parallel_split_synchronization(results[7])

    # TODO communicate to frontend

  end

  # Advanced Branching and Synchronization

  def multichoice_chained()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_multichoice_chained(results[6])
    cf_rust_result = cf_multichoice_chained(results[7])

    # TODO communicate to frontend
  end

  def multichoice_parallel()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_multichoice_parallel(results[6])
    cf_rust_result = cf_multichoice_parallel(results[7])

    # TODO communicate to frontend

  end

  def cancelling_discriminator()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_cancelling_discriminator(results[6])
    cf_rust_result = cf_cancelling_discriminator(results[7])

    # TODO communicate to frontend

  end

  def thread_split_thread_merge()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_thread_split_thread_merge(results[6])
    cf_rust_result = cf_thread_split_thread_merge(results[7])

    # TODO communicate to frontend
  end

  # Multiple Instances

  def multiple_instances_with_design_time_knowledge()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_multiple_instances_with_design_time_knowledge(results[6])
    cf_rust_result = cf_multiple_instances_with_design_time_knowledge(results[7])

    # TODO communicate to frontend
  end

  # Impossible to test against one another
  def multiple_instances_with_runtime_time_knowledge()
  end

  # Impossible to test against one another
  def multiple_instances_without_runtime_time_knowledge()
  end

  def cancelling_partial_join_multiple_instances()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_cancelling_partial_join_multiple_instances(results[6])
    cf_rust_result = cf_cancelling_partial_join_multiple_instances(results[7])

    # TODO communicate to frontend
  end

  # State Based

  def interleaved_routing()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_interleaved_routing(results[6])
    cf_rust_result = cf_interleaved_routing(results[7])

    # TODO communicate to frontend
  end


  def interleaved_parallel_routing()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_interleaved_parallel_routing(results[6])
    cf_rust_result = cf_interleaved_parallel_routing(results[7])

    # TODO communicate to frontend
  end

  def critical_section()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_critical_section(results[6])
    cf_rust_result = cf_critical_section(results[7])

    # TODO communicate to frontend
  end

  # Cancellation and Force Completion

  def cancel_multiple_instance_activity()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_cancel_multiple_instance_activity(results[6])
    cf_rust_result = cf_cancel_multiple_instance_activity(results[7])

    # TODO communicate to frontend
  end

  # Iterations

  def loop_posttest()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_loop_posttest(results[6])
    cf_rust_result = cf_loop_posttest(results[7])

    # TODO communicate to frontend
  end

  def loop_pretest()
    # TODO: setup doc links
    testdoc = ""
    results = run_tests_on(testdoc)

    cf_ruby_result = cf_loop_pretest(results[6])
    cf_rust_result = cf_loop_prettest(results[7])

    # TODO communicate to frontend
  end
end
