require "test_helper"

class WeatherObservationTest < ActiveSupport::TestCase
  test "belongs to weather station" do
    observation = weather_observations(:tempelhof_day_one)

    assert_respond_to observation, :weather_station
    assert_not_nil observation.weather_station
  end

  test "requires observed_on" do
    observation = WeatherObservation.new(
      weather_station: weather_stations(:berlin_tempelhof),
      mean_temperature: 10.0
    )

    assert_not observation.valid?
    assert_includes observation.errors[:observed_on], "can't be blank"
  end

  test "requires at least one weather metric" do
    observation = WeatherObservation.new(
      weather_station: weather_stations(:berlin_tempelhof),
      observed_on: Date.iso8601("2025-02-01")
    )

    assert_not observation.valid?
    assert_includes observation.errors[:base], "At least one weather measurement must be present."
  end

  test "prevents duplicate station observation per day" do
    existing = weather_observations(:tempelhof_day_one)
    duplicate = WeatherObservation.new(
      weather_station: existing.weather_station,
      observed_on: existing.observed_on,
      mean_temperature: 6.3
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:observed_on], "has already been taken"
  end
end
