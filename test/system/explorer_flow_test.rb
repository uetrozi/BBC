require "application_system_test_case"

class ExplorerFlowTest < ApplicationSystemTestCase
  setup do
    BikeCount.delete_all

    station = counting_stations(:one)
    BikeCount.create!(counting_station: station, counted_at: Time.zone.parse("2025-01-01 08:00:00"), count: 10)
    BikeCount.create!(counting_station: station, counted_at: Time.zone.parse("2025-01-01 12:00:00"), count: 20)
    BikeCount.create!(counting_station: station, counted_at: Time.zone.parse("2025-01-02 08:00:00"), count: 5)
  end

  test "user can filter, see results and reset filters" do
    visit explorer_path

    select "02-MI-JAN-N - Jannowitzbrucke Nord", from: "station_id"
    fill_in "from", with: "2025-01-01"
    fill_in "to", with: "2025-01-01"
    click_on "Apply filters"

    assert_text "Matching rows: 2"
    assert_text "Total counted bicycles"
    assert_text "30"
    assert_text "Evaluated days"
    assert_text "1"
    assert_no_text "2025-01-02 08:00"

    click_on "Reset"

    assert_current_path explorer_path
    assert_text "Matching rows: 3"
    assert_text "2025-01-02 08:00"
  end
end
