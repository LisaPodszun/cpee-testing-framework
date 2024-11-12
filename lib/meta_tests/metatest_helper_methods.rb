require_relative "../fixed_tests"
require "test/unit"
require "json"

class TestHelperMethods < Test::Unit::TestCase
  include FixedTests::TestHelpers

  def setup
    # mock data for testing the recursive hash test methods
    @ruby_bag = {"tissues" => 4, "uuid" => 32,"wallet" => {"credit_card" => "expired", "id" => 12345, "membershipcard" => "fitness", "coins" => {"cents" => 10, "euros" => 3, "yen" => 100}}, 
                "lipstick" => "red", "giftcard" => 40}
    @rusty_bag = {"tissues" => 2,"uuid" => 21, "wallet" => {"credit_card" => "expired", "id" => 12356, "photo" => "dog", "coins" => {"cents" => 13, "euros" => 3}}, 
                "lipstick" => "orange", "crab" => "ferris"}
    # mock event logs
    ruby_log_file = File.read('./ruby_log.json')
    @ruby_log = JSON.parse(ruby_log_file)

    rust_log_file = File.read("./rust_log.json")
    @rust_log = JSON.parse(rust_log_file)      
  end


  def test_hash_structure_test
    dif_ruby_to_rust = hash_structure_test([], @ruby_bag, @rusty_bag)
    expected_result_ruby = ["wallet_membershipcard", "wallet_coins_yen", "giftcard"]
    assert_equal(expected_result_ruby, dif_ruby_to_rust, "Structure test of ruby - rust.")

    dif_rust_to_ruby = hash_structure_test([], @rusty_bag, @ruby_bag)
    expected_result_rust = ["wallet_photo", "crab"]
    assert_equal(expected_result_rust, dif_rust_to_ruby, "Structure test of rust - ruby.")
  end


  def test_hash_content_test
    dif_ruby_to_rust = ["wallet_membershipcard", "wallet_coins_yen", "giftcard"]
    dif_rust_to_ruby = ["wallet_photo", "crab"]
    expected_differences = ["tissues", "wallet_id", "wallet_coins_cents", "lipstick"]
    actual = hash_content_test([], @rusty_bag, @ruby_bag, dif_rust_to_ruby, dif_ruby_to_rust)
    assert_equal(expected_differences, actual, "Content test of ruby <-> rust.")
  end

  def test_completeness_test
    expected_dif = {"state/change" => -1, "position/change" => 0, "activity/calling" => 1, "activity/receiving" => 0, "activity/done" => 0, "status/resource_utilization" => 6}
    expected_missing_events_ruby = []
    expected_missing_events_rust = ["status/resource_utilization"]

    actual_dif, actual_missing_events_ruby, actual_missing_events_rust = completeness_test(@rust_log, @ruby_log)

    assert_equal(expected_dif, actual_dif, "Different amounts of events ruby - rust")

    assert_equal(expected_missing_events_ruby, actual_missing_events_ruby, "Missing events in ruby")

    assert_equal(expected_missing_events_rust, actual_missing_events_rust, "Missing events in rust")
  end
  
  def test_events_match
      assert(@ruby_log)
      assert_true(events_match?(@ruby_log["0"], @rust_log["0"]), "The events should match")
      assert_false(events_match?(@ruby_log["0"], @rust_log["15"]), "The events should not match")
  end

  def test_matching
      assert(@ruby_log)
      assert(@rust_log)
      matches = match_logs(@rust_log, @ruby_log, [], ["status/resource_utilization"])

      # ruby to rust matches
      ruby_rust = {0 => 0, 1 => 1, 2 => "only_ruby", 3 => "no_match", 4 => 2, 5 => 3, 6 => "only_ruby", 7 => 4, 8 => 5, 9 => "only_ruby", 10 => 6, 11 => 7, 12 => 8, 13 => "only_ruby", 14 => 9, 15 => 10, 16 => "only_ruby", 17 => 11, 18 => 12, 19 => "only_ruby", 20 => 13, 21 => 14}

      rust_ruby = {0 => 0, 1 => 1, 2 => 4, 3 => 5, 4 => 7, 5 => 8, 6 => 10, 7 => 11, 8 => 12, 9 => 14, 10 => 15, 11 => 17, 12 => 18, 13 => 20, 14 => 21, 15 => "no_match"}
  
      assert_equal(ruby_rust, matches[0])
      assert_equal(rust_ruby, matches[1])
    end

end
