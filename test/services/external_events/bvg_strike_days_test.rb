require "test_helper"

class ExternalEvents::BvgStrikeDaysTest < ActiveSupport::TestCase
  setup do
    ExternalEvents::BvgStrikeDays.reset_cache!
  end

  test "marks all configured strike dates as strike days" do
    strike_dates = %w[
      2025-01-27
      2025-02-10
      2025-02-20
      2025-02-21
      2025-03-19
      2025-03-20
      2025-03-26
      2025-03-27
    ]

    strike_dates.each do |date|
      assert_equal true, ExternalEvents::BvgStrikeDays.strike_day?(date), "expected #{date} to be a strike day"
    end
  end

  test "does not mark non strike days" do
    assert_equal false, ExternalEvents::BvgStrikeDays.strike_day?("2025-03-28")
    assert_equal false, ExternalEvents::BvgStrikeDays.strike_day?("2025-05-01")
  end

  test "returns strike event metadata for strike day" do
    event = ExternalEvents::BvgStrikeDays.event_for("2025-02-20")

    assert_equal Date.iso8601("2025-02-20"), event[:date]
    assert_equal "bvg_strike", event[:type]
    assert_equal "BVG-Warnstreik", event[:label]
    assert_match("U-Bahn, Tram", event[:note])
  end
end
