require "test_helper"

class BikeCounts::WeatherCorrelationAnalysisTest < ActiveSupport::TestCase
  setup do
    BikeCount.delete_all
    WeatherObservation.delete_all
    WeatherStation.delete_all

    @station_one = counting_stations(:one)
    @station_two = counting_stations(:two)
    @weather_station = WeatherStation.create!(external_id: "00433", name: "Berlin-Tempelhof")
  end

  test "builds temperature and precipitation points aligned by date" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 10)
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-02 08:00:00"), count: 20)

    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-01"),
      mean_temperature: 5.0,
      precipitation: 1.2
    )
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-02"),
      mean_temperature: 6.0,
      precipitation: 0.3
    )

    result = analysis(scope: BikeCount.all).call

    assert_equal 2, result.temperature_points.size
    assert_equal 2, result.precipitation_points.size
    assert result.temperature_heatmap.cells.any?
    assert result.precipitation_heatmap.cells.any?
    assert_equal "2025-01-01", result.temperature_points.first[:date]
    assert_equal 10, result.temperature_points.first[:y]
    assert_equal false, result.temperature_points.first[:bvg_strike]
  end

  test "keeps measured zero values for temperature and precipitation" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 12)
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-01"),
      mean_temperature: 0.0,
      precipitation: 0.0
    )

    result = analysis(scope: BikeCount.all).call

    assert_equal [ 0.0 ], result.temperature_points.map { |point| point[:x] }
    assert_equal [ 0.0 ], result.precipitation_points.map { |point| point[:x] }
  end

  test "excludes missing temperature only from temperature points" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 12)
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-01"),
      mean_temperature: nil,
      precipitation: 0.8
    )

    result = analysis(scope: BikeCount.all).call

    assert_equal 0, result.temperature_points.size
    assert_equal 1, result.precipitation_points.size
    assert_empty result.temperature_heatmap.cells
    assert_equal 1, result.precipitation_heatmap.cells.sum { |cell| cell[:days] }
  end

  test "excludes missing precipitation only from precipitation points" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 12)
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-01"),
      mean_temperature: 6.4,
      precipitation: nil
    )

    result = analysis(scope: BikeCount.all).call

    assert_equal 1, result.temperature_points.size
    assert_equal 0, result.precipitation_points.size
    assert_equal 1, result.temperature_heatmap.cells.sum { |cell| cell[:days] }
    assert_empty result.precipitation_heatmap.cells
  end

  test "respects counting station and date filters through scope" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 11)
    BikeCount.create!(counting_station: @station_two, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 99)
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-02 08:00:00"), count: 33)

    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-01"),
      mean_temperature: 5.5,
      precipitation: 1.0
    )
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-01-02"),
      mean_temperature: 7.0,
      precipitation: 0.1
    )

    filter_result = BikeCounts::FilterQuery.new(
      scope: BikeCount.includes(:counting_station),
      params: {
        station_ids: [ @station_one.id.to_s ],
        from: "2025-01-01",
        to: "2025-01-01"
      }
    ).call

    result = analysis(scope: filter_result.scope).call

    assert_equal 1, result.temperature_points.size
    assert_equal 11, result.temperature_points.first[:y]
    assert_equal "2025-01-01", result.temperature_points.first[:date]
    assert_equal 1, result.temperature_heatmap.cells.sum { |cell| cell[:days] }
  end

  test "keeps strike marker only for days inside filtered range" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-02-20 08:00:00"), count: 50)
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-02-22 08:00:00"), count: 60)

    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-02-20"),
      mean_temperature: 7.0,
      precipitation: 0.0
    )
    WeatherObservation.create!(
      weather_station: @weather_station,
      observed_on: Date.iso8601("2025-02-22"),
      mean_temperature: 8.0,
      precipitation: 1.0
    )

    filtered = BikeCount.where(counted_at: Time.zone.parse("2025-02-22 00:00:00")..Time.zone.parse("2025-02-22 23:59:59"))
    result = analysis(scope: filtered).call

    assert_equal 1, result.temperature_points.size
    assert_equal "2025-02-22", result.temperature_points.first[:date]
    assert_equal false, result.temperature_points.first[:bvg_strike]

    unfiltered = analysis(scope: BikeCount.all).call
    strike_point = unfiltered.temperature_points.find { |point| point[:date] == "2025-02-20" }
    assert_equal true, strike_point[:bvg_strike]
  end

  private

  def analysis(scope:)
    BikeCounts::WeatherCorrelationAnalysis.new(
      scope: scope,
      weather_station: @weather_station
    )
  end
end
