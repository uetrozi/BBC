require "test_helper"

class BikeCountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @station_one = counting_stations(:one)
    @station_two = counting_stations(:two)
  end

  test "explorer is available" do
    get explorer_url

    assert_response :success
    assert_includes response.body, "Explorer"
  end

  test "shows imported bike counts" do
    get explorer_url

    assert_response :success
    assert_includes response.body, "data-external-id=\"#{@station_one.external_id}\""
    assert_includes response.body, "data-external-id=\"#{@station_two.external_id}\""
  end

  test "does not show stations without bike count data in station filter" do
    empty_station = CountingStation.create!(
      external_id: "DEMO-EMPTY-01",
      name: "Demo ohne Messwerte"
    )

    get explorer_url

    assert_response :success
    assert_not_includes response.body, "value=\"#{empty_station.id}\""
    assert_not_includes response.body, empty_station.name
  end

  test "filters by counting station" do
    get explorer_url, params: { station_id: @station_one.id }

    assert_response :success
    assert_includes response.body, "data-external-id=\"#{@station_one.external_id}\""
    assert_not_includes response.body, "data-external-id=\"#{@station_two.external_id}\""
  end

  test "filters by multiple counting stations" do
    get explorer_url, params: { station_ids: [ @station_one.id, @station_two.id ] }

    assert_response :success
    assert_includes response.body, "data-external-id=\"#{@station_one.external_id}\""
    assert_includes response.body, "data-external-id=\"#{@station_two.external_id}\""
    assert_includes response.body, "data-chart-datasets="
    assert_includes response.body, @station_one.external_id
    assert_includes response.body, @station_two.external_id
  end

  test "filters by start date" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-02 00:00:00"), count: 99)

    get explorer_url, params: { from: "2025-01-02" }

    assert_response :success
    assert_includes response.body, "data-counted-at=\"2025-01-02T00:00:00Z\""
    assert_not_includes response.body, "data-counted-at=\"2025-01-01T00:00:00Z\""
  end

  test "filters by end date" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-02 00:00:00"), count: 99)

    get explorer_url, params: { to: "2025-01-01" }

    assert_response :success
    assert_includes response.body, "data-counted-at=\"2025-01-01T00:00:00Z\""
    assert_not_includes response.body, "data-counted-at=\"2025-01-02T00:00:00Z\""
  end

  test "applies combined filters and keeps selected values visible" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-01-03 00:00:00"), count: 101)
    BikeCount.create!(counting_station: @station_two, counted_at: Time.zone.parse("2025-01-03 00:00:00"), count: 102)

    get explorer_url, params: {
      station_ids: [ @station_one.id ],
      from: "2025-01-03",
      to: "2025-01-03"
    }

    assert_response :success
    assert_includes response.body, "data-external-id=\"#{@station_one.external_id}\""
    assert_not_includes response.body, "data-external-id=\"#{@station_two.external_id}\""
    assert_includes response.body, "name=\"from\""
    assert_includes response.body, "value=\"2025-01-03\""
    assert_includes response.body, "name=\"to\""
    assert_includes response.body, "option selected=\"selected\" value=\"#{@station_one.id}\""
  end

  test "reset link points to unfiltered explorer view" do
    get explorer_url, params: { station_id: @station_one.id, from: "2025-01-02", to: "2025-01-03" }

    assert_response :success
    assert_includes response.body, "href=\"/explorer\""
  end

  test "shows clear empty state for no matching rows" do
    get explorer_url, params: { from: "2030-01-01", to: "2030-01-02" }

    assert_response :success
    assert_includes response.body, "Keine Messwerte für die gewählten Filter gefunden."
  end

  test "handles invalid date range without server error" do
    get explorer_url, params: { from: "2025-01-03", to: "2025-01-01" }

    assert_response :success
    assert_includes response.body, "End date must be on or after start date."
    assert_includes response.body, "Keine Messwerte für die gewählten Filter gefunden."
  end

  test "handles unknown counting station id without server error" do
    get explorer_url, params: { station_id: 999_999 }

    assert_response :success
    assert_includes response.body, "Unknown counting station ID: 999999."
    assert_includes response.body, "Unknown station (ID 999999)"
    assert_includes response.body, "Keine Messwerte für die gewählten Filter gefunden."
  end

  test "handles non numeric page parameter gracefully" do
    get explorer_url, params: { page: "not-a-number" }

    assert_response :success
    assert_includes response.body, "Explorer"
  end

  test "handles non numeric station id gracefully" do
    get explorer_url, params: { station_id: "abc" }

    assert_response :success
    assert_includes response.body, "Counting station ID must be a positive integer."
    assert_includes response.body, "Keine Messwerte für die gewählten Filter gefunden."
  end

  test "limits station comparison selection size" do
    get explorer_url, params: { station_ids: [ 1, 2, 3, 4, 5, 6 ] }

    assert_response :success
    assert_includes response.body, "Please select at most 5 counting stations for comparison."
    assert_includes response.body, "Keine Messwerte für die gewählten Filter gefunden."
  end

  test "handles empty database without server error" do
    BikeCount.delete_all
    CountingStation.delete_all

    get explorer_url

    assert_response :success
    assert_includes response.body, "Gefundene Messwerte:"
    assert_includes response.body, "Keine Messwerte für die gewählten Filter gefunden."
  end

  test "paginates and keeps filter params in pagination links" do
    BikeCount.delete_all
    110.times do |index|
      BikeCount.create!(
        counting_station: @station_one,
        counted_at: Time.zone.parse("2025-01-01 00:00:00") + index.hours,
        count: index
      )
    end

    get explorer_url, params: { station_ids: [ @station_one.id ], from: "2025-01-01", to: "2025-01-31" }

    assert_response :success
    assert_includes response.body, "Seite 1 von 2"
    assert_includes response.body, "station_ids%5B%5D=#{@station_one.id}"
    assert_includes response.body, "from=2025-01-01"
    assert_includes response.body, "to=2025-01-31"
    assert_includes response.body, "page=2"

    get explorer_url, params: { station_ids: [ @station_one.id ], from: "2025-01-01", to: "2025-01-31", page: 2 }

    assert_response :success
    assert_includes response.body, "Seite 2 von 2"
    assert_not_includes response.body, "data-counted-at=\"2025-01-05T13:00:00Z\""
  end
end
