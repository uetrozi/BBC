require "test_helper"

class BikeCountTest < ActiveSupport::TestCase
  test "belongs to counting station" do
    bike_count = bike_counts(:one)

    assert_respond_to bike_count, :counting_station
    assert_not_nil bike_count.counting_station
  end

  test "requires counted_at and non-negative integer count" do
    bike_count = BikeCount.new(counting_station: counting_stations(:one), count: -2)

    assert_not bike_count.valid?
    assert_includes bike_count.errors[:counted_at], "can't be blank"
    assert_includes bike_count.errors[:count], "must be greater than or equal to 0"
  end

  test "prevents duplicate station measurement at same timestamp" do
    existing = bike_counts(:one)
    duplicate = BikeCount.new(
      counting_station: existing.counting_station,
      counted_at: existing.counted_at,
      count: 99
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:counted_at], "has already been taken"
  end
end
