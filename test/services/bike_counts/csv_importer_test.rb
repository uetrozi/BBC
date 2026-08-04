require "test_helper"
require "tempfile"

class BikeCounts::CsvImporterTest < ActiveSupport::TestCase
  setup do
    BikeCount.delete_all
    CountingStation.delete_all
  end

  test "imports valid rows and returns summary" do
    result = BikeCounts::CsvImporter.call(fixture_path("bbcx_valid_import.csv"))

    assert_equal 4, result.rows_read
    assert_equal 4, result.imported_rows
    assert_equal 0, result.skipped_duplicates
    assert_equal 0, result.invalid_rows
    assert_empty result.errors

    assert_equal 2, CountingStation.count
    assert_equal 4, BikeCount.count
  end

  test "collects errors for invalid rows and keeps processing" do
    result = BikeCounts::CsvImporter.call(fixture_path("bbcx_invalid_rows.csv"))

    assert_equal 3, result.rows_read
    assert_equal 0, result.imported_rows
    assert_equal 0, result.skipped_duplicates
    assert_equal 3, result.invalid_rows
    assert_equal 3, result.errors.size
  end

  test "skips duplicates and reports summary" do
    result = BikeCounts::CsvImporter.call(fixture_path("bbcx_duplicate_rows.csv"))

    assert_equal 2, result.rows_read
    assert_equal 1, result.imported_rows
    assert_equal 1, result.skipped_duplicates
    assert_equal 0, result.invalid_rows
  end

  test "imports valid rows and skips invalid rows in same file" do
    csv_path = write_temp_csv(<<~CSV)
      counted_at,station_external_id,station_name,count
      2025-01-01T00:00:00Z,10-AB-XYZ-N,Alpha,10
      invalid-date,10-AB-XYZ-N,Alpha,12
      2025-01-02T00:00:00Z,10-AB-XYZ-N,Alpha,15
    CSV

    result = BikeCounts::CsvImporter.call(csv_path)

    assert_equal 3, result.rows_read
    assert_equal 2, result.imported_rows
    assert_equal 0, result.skipped_duplicates
    assert_equal 1, result.invalid_rows
    assert_equal 2, BikeCount.count
  end

  test "ignores additional unknown columns" do
    csv_path = write_temp_csv(<<~CSV)
      counted_at,station_external_id,station_name,count,unexpected_column
      2025-01-01T00:00:00Z,10-AB-XYZ-N,Alpha,11,ignored
    CSV

    result = BikeCounts::CsvImporter.call(csv_path)

    assert_equal 1, result.rows_read
    assert_equal 1, result.imported_rows
    assert_equal 0, result.invalid_rows
  end

  test "rejects missing required headers with clear message" do
    csv_path = write_temp_csv(<<~CSV)
      counted_at,station_external_id,count
      2025-01-01T00:00:00Z,10-AB-XYZ-N,10
    CSV

    error = assert_raises(ArgumentError) { BikeCounts::CsvImporter.call(csv_path) }

    assert_includes error.message, "missing required headers"
    assert_includes error.message, "station_name"
  end

  test "rejects empty file with clear message" do
    csv_path = write_temp_csv("")

    error = assert_raises(ArgumentError) { BikeCounts::CsvImporter.call(csv_path) }

    assert_equal "CSV file is empty.", error.message
  end

  test "rejects malformed csv content with clear message" do
    csv_path = write_temp_csv("counted_at,station_external_id,station_name,count\n\"broken,10-AB-XYZ-N,Alpha,1\n")

    error = assert_raises(ArgumentError) { BikeCounts::CsvImporter.call(csv_path) }

    assert_match(/CSV|Unclosed quoted field|Illegal quoting/, error.message)
  end

  test "rejects invalid encoding with clear message" do
    file = Tempfile.new([ "bbcx-invalid-encoding", ".csv" ])
    file.binmode
    file.write("\xFF\xFEcounted_at,station_external_id,station_name,count\n")
    file.flush
    @temp_files ||= []
    @temp_files << file

    error = assert_raises(ArgumentError) { BikeCounts::CsvImporter.call(file.path) }

    assert_equal "CSV encoding is invalid. Please provide UTF-8 encoded CSV content.", error.message
  end

  private

  def fixture_path(file_name)
    Rails.root.join("test", "fixtures", "files", file_name)
  end

  def write_temp_csv(content)
    file = Tempfile.new([ "bbcx-import", ".csv" ])
    file.write(content)
    file.flush
    @temp_files ||= []
    @temp_files << file
    file.path
  end

  teardown do
    Array(@temp_files).each(&:close!)
  end
end
