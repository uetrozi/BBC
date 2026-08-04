require "test_helper"

class CountingStationTest < ActiveSupport::TestCase
  test "has many bike counts" do
    station = counting_stations(:one)

    assert_respond_to station, :bike_counts
    assert station.bike_counts.any?
  end

  test "requires external_id and name" do
    station = CountingStation.new

    assert_not station.valid?
    assert_includes station.errors[:external_id], "can't be blank"
    assert_includes station.errors[:name], "can't be blank"
  end

  test "external_id must be unique" do
    duplicate = CountingStation.new(
      external_id: counting_stations(:one).external_id,
      name: "Duplicate"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end
end
