require "test_helper"

class BikeCounts::WeatherAnalysisTest < ActiveSupport::TestCase
  setup do
    BikeCount.delete_all
    WeatherObservation.delete_all
    WeatherStation.delete_all

    @station_one = counting_stations(:one)
    @station_two = counting_stations(:two)
    @weather_station = WeatherStation.create!(external_id: "00433", name: "Berlin-Tempelhof")
  end

  test "maps weather observations to aggregated bike days by date" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 10)
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 12:00:00"), count: 15)
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-02 08:00:00"), count: 7)

    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-01"),
      mean_temperature: 2.5,
      precipitation: 0.0
    )

    rows = BikeCounts::WeatherAnalysis.new(scope: BikeCount.all, weather_station: @weather_station).call

    assert_equal [
      {
        date: "2025-01-01",
        bike_count: 25,
        mean_temperature: 2.5,
        precipitation: 0.0,
        bvg_strike: false,
        bvg_strike_label: nil,
        bvg_strike_note: nil
      },
      {
        date: "2025-01-02",
        bike_count: 7,
        mean_temperature: nil,
        precipitation: nil,
        bvg_strike: false,
        bvg_strike_label: nil,
        bvg_strike_note: nil
      }
    ], rows.map(&:to_h)
  end

  test "does not emit rows for weather days without bike counts" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 11)
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-03"),
      mean_temperature: 4.0,
      precipitation: 3.2
    )

    rows = BikeCounts::WeatherAnalysis.new(scope: BikeCount.all, weather_station: @weather_station).call

    assert_equal [ "2025-01-01" ], rows.map(&:date)
  end

  test "respects counting station filter" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 10)
    BikeCount.create!(counting_station: @station_two, counted_at: Time.zone.parse("2025-01-01 09:00:00"), count: 30)

    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-01"),
      mean_temperature: 5.0,
      precipitation: 1.0
    )

    rows = BikeCounts::WeatherAnalysis.new(
      scope: BikeCount.where(counting_station_id: @station_one.id),
      weather_station: @weather_station
    ).call

    assert_equal 10, rows.first.bike_count
    assert_equal 5.0, rows.first.mean_temperature
  end

  test "respects date filter" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 10)
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-03 08:00:00"), count: 20)
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-03"),
      mean_temperature: 7.5,
      precipitation: 0.0
    )

    rows = BikeCounts::WeatherAnalysis.new(
      scope: BikeCount.where(counted_at: Time.zone.parse("2025-01-02 00:00:00")..Time.zone.parse("2025-01-03 23:59:59")),
      weather_station: @weather_station
    ).call

    assert_equal 1, rows.size
    assert_equal "2025-01-03", rows.first.date
    assert_equal 20, rows.first.bike_count
    assert_equal 7.5, rows.first.mean_temperature
  end

  test "works with existing filter query output" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 10)
    BikeCount.create!(counting_station: @station_two, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 30)
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-01"),
      mean_temperature: 6.0,
      precipitation: 0.4
    )

    filter_result = BikeCounts::FilterQuery.new(
      scope: BikeCount.includes(:counting_station),
      params: {
        station_ids: [ @station_two.id.to_s ],
        from: "2025-01-01",
        to: "2025-01-01"
      }
    ).call

    rows = BikeCounts::WeatherAnalysis.new(
      scope: filter_result.scope,
      weather_station: @weather_station
    ).call

    assert_equal 1, rows.size
    assert_equal 30, rows.first.bike_count
    assert_equal 6.0, rows.first.mean_temperature
    assert_equal 0.4, rows.first.precipitation
  end

  test "marks strike days in weather rows" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-27 08:00:00"), count: 21)
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-27"),
      mean_temperature: 6.0,
      precipitation: 0.0
    )

    rows = BikeCounts::WeatherAnalysis.new(scope: BikeCount.all, weather_station: @weather_station).call

    assert_equal true, rows.first.bvg_strike
    assert_equal "BVG-Warnstreik", rows.first.bvg_strike_label
  end
end
