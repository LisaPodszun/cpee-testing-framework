require 'json'
require_relative 'fixed_tests'

module TestCases
  include TestHelpers
  START =  "https://cpee.org/flow/start/url/"
  
  def test_service_call(data,testinstance)
    # TODO: setup doc links
    doc_url_ruby = "https://raw.githubusercontent.com/LisaPodszun/cpee-testing-framework/refs/heads/main/testsets/Ruby/OwnBasic/service_call.xml"
    doc_url_rust = "https://raw.githubusercontent.com/LisaPodszun/cpee-testing-framework/refs/heads/main/testsets/Rust/OwnBasic/service_call.xml"
    
    results = run_tests_on(START, doc_url_ruby, "ruby", START, doc_url_rust, "rust", data)
    
    cf_ruby_result = cf_service_call(results[6])
    cf_rust_result = cf_service_call(results[7])

    testinstance[:result] = JSON::encode(results)

    puts "Passed control flow tests?"
    puts cf_ruby_result
    puts "Passed control flow tests a second time?"
    puts cf_rust_result

    p "ran all tests successfully"
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
