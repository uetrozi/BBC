require "test_helper"
require "tempfile"

class Weather::DwdImporterTest < ActiveSupport::TestCase
  setup do
    WeatherObservation.delete_all
    WeatherStation.delete_all
  end

  test "imports valid temperature and precipitation values with summary" do
    result = Weather::DwdImporter.call(fixture_path("produkt_klima_tag_20250101_20250105_00433.txt"))

    assert_equal 6, result.rows_read
    assert_equal 3, result.imported_rows
    assert_equal 1, result.skipped_duplicates
    assert_equal 2, result.invalid_rows
    assert_equal 2, result.errors.size

    station = WeatherStation.find_by!(external_id: "00433")
    assert_equal "Berlin-Tempelhof", station.name

    day_one = WeatherObservation.find_by!(weather_station: station, observed_on: Date.iso8601("2025-01-01"))
    assert_equal 2.5, day_one.mean_temperature.to_f
    assert_equal 0.0, day_one.precipitation.to_f
  end

  test "keeps missing DWD values as nil instead of 0" do
    Weather::DwdImporter.call(fixture_path("produkt_klima_tag_20250101_20250105_00433.txt"))
    station = WeatherStation.find_by!(external_id: "00433")

    day_two = WeatherObservation.find_by!(weather_station: station, observed_on: Date.iso8601("2025-01-02"))
    day_three = WeatherObservation.find_by!(weather_station: station, observed_on: Date.iso8601("2025-01-03"))

    assert_nil day_two.mean_temperature
    assert_equal 1.7, day_two.precipitation.to_f
    assert_equal 3.1, day_three.mean_temperature.to_f
    assert_nil day_three.precipitation
  end

  test "detects duplicates on repeated import run" do
    Weather::DwdImporter.call(fixture_path("produkt_klima_tag_20250101_20250105_00433.txt"))
    result = Weather::DwdImporter.call(fixture_path("produkt_klima_tag_20250101_20250105_00433.txt"))

    assert_equal 6, result.rows_read
    assert_equal 0, result.imported_rows
    assert_equal 4, result.skipped_duplicates
    assert_equal 2, result.invalid_rows
  end

  test "imports DWD product from zip archive" do
    zip_file = Tempfile.new([ "dwd-weather", ".zip" ])
    zip_file.close

    Zip::File.open(zip_file.path, create: true) do |archive|
      archive.add("produkt_klima_tag_20250101_20250105_00433.txt", fixture_path("produkt_klima_tag_20250101_20250105_00433.txt"))
      archive.add("Metadaten_Stationsname_Betreibername_00433.txt", fixture_path("Metadaten_Stationsname_Betreibername_00433.txt"))
    end

    result = Weather::DwdImporter.call(zip_file.path)

    assert_equal 6, result.rows_read
    assert_equal 3, result.imported_rows
    assert_equal "Berlin-Tempelhof", WeatherStation.find_by!(external_id: "00433").name
  ensure
    zip_file&.unlink
  end

  test "raises helpful error when file does not exist" do
    error = assert_raises(ArgumentError) { Weather::DwdImporter.call("missing-dwd-file.txt") }

    assert_equal "Import file does not exist.", error.message
  end

  private

  def fixture_path(file_name)
    Rails.root.join("test", "fixtures", "files", "dwd", file_name)
  end
end
