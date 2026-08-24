require "test_helper"
require "nokogiri"

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

  test "restricts calendar selection to year 2025 in date fields" do
    get explorer_url

    assert_response :success
    assert_includes response.body, "name=\"from\""
    assert_includes response.body, "min=\"2025-01-01\""
    assert_includes response.body, "max=\"2025-12-31\""
    assert_includes response.body, "name=\"to\""
  end

  test "renders weather analysis section with both scatterplots" do
    get explorer_url

    assert_response :success
    assert_includes response.body, "Wetter &amp; Radverkehr"
    assert_includes response.body, "Temperatur und Radverkehr"
    assert_includes response.body, "Niederschlag und Radverkehr"
    assert_includes response.body, "data-weather-scatter-kind=\"temperature\""
    assert_includes response.body, "data-weather-scatter-kind=\"precipitation\""
    assert_includes response.body, "data-chart-points="
    assert_includes response.body, "△ BVG-Warnstreik"
    assert_includes response.body, "Ausgewertete Tage: <strong>1</strong>"
    assert_includes response.body, "Korrelation: <strong>Nicht ausreichend Daten</strong>"
  end

  test "includes strike markers in chart payloads only for included dates" do
    BikeCount.create!(counting_station: @station_one, counted_at: Time.zone.parse("2025-02-20 08:00:00"), count: 88)
    WeatherStation.find_or_create_by!(external_id: "00433") { |station| station.name = "Berlin-Tempelhof" }
    weather_station = WeatherStation.find_by!(external_id: "00433")
    WeatherObservation.create!(
      weather_station: weather_station,
      observed_on: Date.iso8601("2025-02-20"),
      mean_temperature: 7.0,
      precipitation: 0.0
    )

    get explorer_url, params: { from: "2025-02-20", to: "2025-02-20", station_ids: [ @station_one.id ] }

    assert_response :success
    assert_includes response.body, "bvg_strike&quot;:true"
    assert_includes response.body, "BVG-Warnstreik"

    get explorer_url, params: { from: "2025-02-22", to: "2025-02-22", station_ids: [ @station_one.id ] }

    assert_response :success
    assert_not_includes response.body, "bvg_strike&quot;:true"
  end

  test "shows clear weather empty state when no observations are available" do
    WeatherObservation.delete_all

    get explorer_url

    assert_response :success
    assert_includes response.body, "Für den aktuellen Filter sind keine Temperaturwerte verfügbar."
    assert_includes response.body, "Für den aktuellen Filter sind keine Niederschlagswerte verfügbar."
    assert_includes response.body, "Korrelation: <strong>Nicht ausreichend Daten</strong>"
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

  test "does not show demo stations in station filter even when they contain data" do
    demo_station = CountingStation.create!(
      external_id: "DEMO-01-JAN-N",
      name: "Jannowitzbrücke Nord (Demo)"
    )
    BikeCount.create!(
      counting_station: demo_station,
      counted_at: Time.zone.parse("2025-05-01 08:00:00"),
      count: 42
    )

    get explorer_url

    assert_response :success
    assert_not_includes response.body, "<option value=\"#{demo_station.id}\">"
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

  test "month quick select expands to contiguous month range" do
    get explorer_url, params: { station_ids: [ @station_one.id ], from: "2025-01-01", to: "2025-01-31" }

    assert_response :success

    document = Nokogiri::HTML(response.body)
    march_link = document.css("a.secondary-link").find { |link| link.text.strip == "Mär 2025" }

    assert march_link.present?
    assert_includes march_link["href"], "from=2025-01-01"
    assert_includes march_link["href"], "to=2025-03-31"
    assert_includes march_link["href"], "station_ids%5B%5D=#{@station_one.id}"
  end

  test "month quick select deselects a single selected month" do
    get explorer_url, params: { station_ids: [ @station_one.id ], from: "2025-03-01", to: "2025-03-31" }

    assert_response :success

    document = Nokogiri::HTML(response.body)
    march_link = document.css("a.secondary-link").find { |link| link.text.strip == "Mär 2025" }

    assert march_link.present?
    assert_not_includes march_link["href"], "from="
    assert_not_includes march_link["href"], "to="
    assert_includes march_link["href"], "station_ids%5B%5D=#{@station_one.id}"
  end

  test "month quick select shrinks range when clicking selected edge month" do
    get explorer_url, params: { station_ids: [ @station_one.id ], from: "2025-01-01", to: "2025-03-31" }

    assert_response :success

    document = Nokogiri::HTML(response.body)
    march_link = document.css("a.secondary-link").find { |link| link.text.strip == "Mär 2025" }

    assert march_link.present?
    assert_includes march_link["href"], "from=2025-01-01"
    assert_includes march_link["href"], "to=2025-02-28"
    assert_includes march_link["href"], "station_ids%5B%5D=#{@station_one.id}"
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

  test "rejects start date before allowed range" do
    get explorer_url, params: { from: "2024-12-31", to: "2025-01-02" }

    assert_response :success
    assert_includes response.body, "Start date must be between 2025-01-01 and 2025-12-31."
    assert_includes response.body, "Keine Messwerte für die gewählten Filter gefunden."
  end

  test "rejects end date after allowed range" do
    get explorer_url, params: { from: "2025-12-30", to: "2026-01-01" }

    assert_response :success
    assert_includes response.body, "End date must be between 2025-01-01 and 2025-12-31."
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
    assert_includes response.body, "Explorer"
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
