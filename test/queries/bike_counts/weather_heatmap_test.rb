require "test_helper"

class BikeCounts::WeatherHeatmapTest < ActiveSupport::TestCase
  test "bins temperature values across boundaries including below and exactly zero" do
    rows = [
      row(temp: -0.1, rain: 0.0, bikes: 1200),
      row(temp: 0.0, rain: 0.0, bikes: 1200),
      row(temp: 4.9, rain: 0.0, bikes: 1200),
      row(temp: 5.0, rain: 0.0, bikes: 1200),
      row(temp: 9.9, rain: 0.0, bikes: 1200),
      row(temp: 10.0, rain: 0.0, bikes: 1200),
      row(temp: 14.9, rain: 0.0, bikes: 1200),
      row(temp: 15.0, rain: 0.0, bikes: 1200),
      row(temp: 19.9, rain: 0.0, bikes: 1200),
      row(temp: 20.0, rain: 0.0, bikes: 1200),
      row(temp: 24.9, rain: 0.0, bikes: 1200),
      row(temp: 25.0, rain: 0.0, bikes: 1200),
      row(temp: 29.9, rain: 0.0, bikes: 1200),
      row(temp: 30.0, rain: 0.0, bikes: 1200)
    ]

    result = BikeCounts::WeatherHeatmap.new(rows: rows).temperature_result
    labels = result.cells.map { |cell| cell[:weather_bin] }.uniq

    assert_includes labels, "unter 0 °C"
    assert_includes labels, "0 bis <5 °C"
    assert_includes labels, "5 bis <10 °C"
    assert_includes labels, "10 bis <15 °C"
    assert_includes labels, "15 bis <20 °C"
    assert_includes labels, "20 bis <25 °C"
    assert_includes labels, "25 bis <30 °C"
    assert_includes labels, "ab 30 °C"
  end

  test "bins precipitation values across all configured classes and boundary values" do
    rows = [
      row(temp: 10.0, rain: 0.0, bikes: 1000),
      row(temp: 10.0, rain: 1.0, bikes: 1000),
      row(temp: 10.0, rain: 3.0, bikes: 1000),
      row(temp: 10.0, rain: 5.0, bikes: 1000),
      row(temp: 10.0, rain: 10.0, bikes: 1000),
      row(temp: 10.0, rain: 20.0, bikes: 1000),
      row(temp: 10.0, rain: 0.8, bikes: 1000),
      row(temp: 10.0, rain: 1.1, bikes: 1000),
      row(temp: 10.0, rain: 3.1, bikes: 1000),
      row(temp: 10.0, rain: 5.1, bikes: 1000),
      row(temp: 10.0, rain: 10.1, bikes: 1000),
      row(temp: 10.0, rain: 20.1, bikes: 1000),
      row(temp: 10.0, rain: 22.0, bikes: 1000)
    ]

    result = BikeCounts::WeatherHeatmap.new(rows: rows).precipitation_result
    labels = result.cells.map { |cell| cell[:weather_bin] }.uniq

    assert_includes labels, "0 mm"
    assert_includes labels, ">0 bis 1 mm"
    assert_includes labels, ">1 bis 3 mm"
    assert_includes labels, ">3 bis 5 mm"
    assert_includes labels, ">5 bis 10 mm"
    assert_includes labels, ">10 bis 20 mm"
    assert_includes labels, "über 20 mm"

    counts = result.cells.group_by { |cell| cell[:weather_bin] }.transform_values { |cells| cells.sum { |cell| cell[:days] } }
    assert_equal 1, counts["0 mm"]
    assert_equal 2, counts[">0 bis 1 mm"]
    assert_equal 2, counts[">1 bis 3 mm"]
    assert_equal 2, counts[">3 bis 5 mm"]
    assert_equal 2, counts[">5 bis 10 mm"]
    assert_equal 2, counts[">10 bis 20 mm"]
    assert_equal 2, counts["über 20 mm"]
  end

  test "uses 1000 step bike bins and adapts upper bound to max value" do
    rows = [
      row(temp: 10.0, rain: 0.0, bikes: 50),
      row(temp: 10.0, rain: 0.0, bikes: 999),
      row(temp: 10.0, rain: 0.0, bikes: 1000),
      row(temp: 10.0, rain: 0.0, bikes: 4100)
    ]

    result = BikeCounts::WeatherHeatmap.new(rows: rows).temperature_result

    assert_equal [ "0–999", "1.000–1.999", "2.000–2.999", "3.000–3.999", "4.000–4.999" ], result.y_labels
  end

  test "aggregates multiple days in the same cell and separates different bins" do
    rows = [
      row(temp: 16.2, rain: 0.0, bikes: 4200),
      row(temp: 17.9, rain: 0.0, bikes: 4300),
      row(temp: 22.0, rain: 0.0, bikes: 4300)
    ]

    result = BikeCounts::WeatherHeatmap.new(rows: rows).temperature_result
    grouped = result.cells.index_by { |cell| [ cell[:weather_bin], cell[:bike_bin] ] }

    assert_equal 2, grouped[[ "15 bis <20 °C", "4.000–4.999" ]][:days]
    assert_equal 1, grouped[[ "20 bis <25 °C", "4.000–4.999" ]][:days]
  end

  test "excludes missing temperature only from temperature heatmap" do
    rows = [
      row(temp: nil, rain: 0.0, bikes: 3000),
      row(temp: 12.0, rain: 0.0, bikes: 3000)
    ]

    result = BikeCounts::WeatherHeatmap.new(rows: rows).temperature_result

    assert_equal 1, result.cells.sum { |cell| cell[:days] }
  end

  test "excludes missing precipitation only from precipitation heatmap" do
    rows = [
      row(temp: 12.0, rain: nil, bikes: 3000),
      row(temp: 12.0, rain: 0.0, bikes: 3000)
    ]

    result = BikeCounts::WeatherHeatmap.new(rows: rows).precipitation_result

    assert_equal 1, result.cells.sum { |cell| cell[:days] }
    assert_equal "0 mm", result.cells.first[:weather_bin]
  end

  private

  def row(temp:, rain:, bikes:)
    BikeCounts::WeatherAnalysis::Row.new(
      date: "2025-01-01",
      bike_count: bikes,
      mean_temperature: temp,
      precipitation: rain
    )
  end
end
