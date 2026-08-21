require "test_helper"

class WeatherStationTest < ActiveSupport::TestCase
  test "has many weather observations" do
    station = weather_stations(:berlin_tempelhof)

    assert_respond_to station, :weather_observations
    assert station.weather_observations.any?
  end

  test "requires external_id and name" do
    station = WeatherStation.new

    assert_not station.valid?
    assert_includes station.errors[:external_id], "can't be blank"
    assert_includes station.errors[:name], "can't be blank"
  end

  test "external_id must be unique" do
    duplicate = WeatherStation.new(
      external_id: weather_stations(:berlin_tempelhof).external_id,
      name: "Duplicate Station"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end
end
