require_relative "../fixed_tests"
require "test/unit"

class TestHelperMethods < Test::Unit::TestCase
  include FixedTests::TestHelpers

  def setup
    # mock data for testing the recursive hash test methods
    @ruby_bag = {"tissues" => 4, "uuid" => 32,"wallet" => {"credit_card" => "expired", "id" => 12345, "membershipcard" => "fitness", "coins" => {"cents" => 10, "euros" => 3, "yen" => 100}}, 
                "lipstick" => "red", "giftcard" => 40}
    @rusty_bag = {"tissues" => 2,"uuid" => 21, "wallet" => {"credit_card" => "expired", "id" => 12356, "photo" => "dog", "coins" => {"cents" => 13, "euros" => 3}}, 
                "lipstick" => "orange", "crab" => "ferris"}
    # mock event logs for completeness test
    @ruby_log = {0 => {"channel" => "A"}, 1 => {"channel" => "B"}, 2 => {"channel" => "C"}}
    @rust_log = {0 => {"channel" => "B"}, 1 => {"channel" => "B"}, 2 => {"channel" => "C"}, 3 => {"channel" => "D"}}
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
    expected_dif = {"A" => 1, "B" => -1, "C" => 0, "D" => -1}
    expected_missing_events_ruby = ["D"]
    expected_missing_events_rust = ["A"]

    actual_dif, actual_missing_events_ruby, actual_missing_events_rust = completeness_test(@rust_log, @ruby_log)

    assert_equal(expected_dif, actual_dif, "Different amounts of events ruby - rust")

    assert_equal(expected_missing_events_ruby, actual_missing_events_ruby, "Missing events in ruby")

    assert_equal(expected_missing_events_rust, actual_missing_events_rust, "Missing events in rust")
  end
  
end
