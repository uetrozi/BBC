require "test_helper"

class BikeCounts::StatisticsTest < ActiveSupport::TestCase
  setup do
    BikeCount.delete_all
    @station_one = counting_stations(:one)
    @station_two = counting_stations(:two)
  end

  test "calculates total counted bicycles" do
    create_count(@station_one, "2025-01-01 08:00:00", 10)
    create_count(@station_one, "2025-01-02 08:00:00", 15)

    statistics = BikeCounts::Statistics.new(scope: BikeCount.all).call

    assert_equal 25, statistics.total_bikes
  end

  test "aggregates multiple measurements per day before statistics" do
    create_count(@station_one, "2025-01-01 08:00:00", 10)
    create_count(@station_one, "2025-01-01 12:00:00", 6)
    create_count(@station_one, "2025-01-02 08:00:00", 5)

    statistics = BikeCounts::Statistics.new(scope: BikeCount.all).call

    assert_equal [
      {
        date: "2025-01-01",
        count: 16,
        bvg_strike: false,
        bvg_strike_label: nil,
        bvg_strike_note: nil
      },
      {
        date: "2025-01-02",
        count: 5,
        bvg_strike: false,
        bvg_strike_label: nil,
        bvg_strike_note: nil
      }
    ], statistics.daily_series
  end

  test "calculates average based on daily totals" do
    create_count(@station_one, "2025-01-01 08:00:00", 10)
    create_count(@station_one, "2025-01-01 12:00:00", 10)
    create_count(@station_one, "2025-01-02 08:00:00", 10)

    statistics = BikeCounts::Statistics.new(scope: BikeCount.all).call

    assert_in_delta 15.0, statistics.average_per_day.to_f, 0.001
  end

  test "returns strongest day by highest daily total" do
    create_count(@station_one, "2025-01-01 08:00:00", 10)
    create_count(@station_one, "2025-01-02 08:00:00", 30)

    statistics = BikeCounts::Statistics.new(scope: BikeCount.all).call

    assert_equal Date.iso8601("2025-01-02"), statistics.strongest_day[:date]
    assert_equal 30, statistics.strongest_day[:count]
  end

  test "returns number of evaluated days" do
    create_count(@station_one, "2025-01-01 08:00:00", 10)
    create_count(@station_one, "2025-01-01 12:00:00", 20)
    create_count(@station_one, "2025-01-03 08:00:00", 5)

    statistics = BikeCounts::Statistics.new(scope: BikeCount.all).call

    assert_equal 2, statistics.evaluated_days
  end

  test "respects station filter" do
    create_count(@station_one, "2025-01-01 08:00:00", 10)
    create_count(@station_two, "2025-01-01 08:00:00", 50)

    statistics = BikeCounts::Statistics.new(scope: BikeCount.where(counting_station_id: @station_one.id)).call

    assert_equal 10, statistics.total_bikes
  end

  test "respects date filter" do
    create_count(@station_one, "2025-01-01 08:00:00", 10)
    create_count(@station_one, "2025-01-03 08:00:00", 20)

    statistics = BikeCounts::Statistics.new(
      scope: BikeCount.where(counted_at: Time.zone.parse("2025-01-02 00:00:00")..Time.zone.parse("2025-01-03 23:59:59"))
    ).call

    assert_equal 20, statistics.total_bikes
    assert_equal [
      {
        date: "2025-01-03",
        count: 20,
        bvg_strike: false,
        bvg_strike_label: nil,
        bvg_strike_note: nil
      }
    ], statistics.daily_series
  end

  test "returns daily series in chronological order" do
    create_count(@station_one, "2025-01-03 08:00:00", 7)
    create_count(@station_one, "2025-01-01 08:00:00", 5)
    create_count(@station_one, "2025-01-02 08:00:00", 6)

    statistics = BikeCounts::Statistics.new(scope: BikeCount.all).call

    assert_equal [ "2025-01-01", "2025-01-02", "2025-01-03" ], statistics.daily_series.map { |day| day[:date] }
  end

  test "marks bvg strike days in daily series" do
    create_count(@station_one, "2025-01-27 08:00:00", 80)
    create_count(@station_one, "2025-01-28 08:00:00", 40)

    statistics = BikeCounts::Statistics.new(scope: BikeCount.all).call

    strike_day = statistics.daily_series.find { |day| day[:date] == "2025-01-27" }
    regular_day = statistics.daily_series.find { |day| day[:date] == "2025-01-28" }

    assert_equal true, strike_day[:bvg_strike]
    assert_equal "BVG-Warnstreik", strike_day[:bvg_strike_label]
    assert_equal false, regular_day[:bvg_strike]
  end

  test "returns empty and non misleading values for empty scope" do
    statistics = BikeCounts::Statistics.new(scope: BikeCount.none).call

    assert_equal 0, statistics.total_bikes
    assert_nil statistics.average_per_day
    assert_equal 0, statistics.evaluated_days
    assert_nil statistics.strongest_day
    assert_equal [], statistics.daily_series
  end

  test "resolves strongest day ties to earlier day" do
    create_count(@station_one, "2025-01-02 08:00:00", 20)
    create_count(@station_one, "2025-01-03 08:00:00", 20)

    statistics = BikeCounts::Statistics.new(scope: BikeCount.all).call

    assert_equal Date.iso8601("2025-01-02"), statistics.strongest_day[:date]
    assert_equal 20, statistics.strongest_day[:count]
  end

  private

  def create_count(station, counted_at, count)
    BikeCount.create!(
      counting_station: station,
      counted_at: Time.zone.parse(counted_at),
      count: count
    )
  end
end
