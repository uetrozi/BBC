require "test_helper"
require "csv"

class BikeCounts::XlsxNormalizerTest < ActiveSupport::TestCase
  test "normalizes yearly xlsx sheet to import csv" do
    output_path = Rails.root.join("tmp", "bbcx_normalized_test_2025.csv")
    File.delete(output_path) if output_path.exist?

    result = BikeCounts::XlsxNormalizer.call(
      input_path: fixture_path("bbcx_sample_source.xlsx"),
      year: 2025,
      output_path: output_path
    )

    assert_equal 3, result.rows_read
    assert_equal 4, result.rows_written
    assert_equal 2, result.rows_skipped
    assert_equal output_path.to_s, result.output_path
    assert output_path.exist?

    csv_rows = CSV.read(output_path, headers: true)
    assert_equal 4, csv_rows.size
    assert_equal Time.zone.parse("2025-01-01 00:00:00"), Time.zone.parse(csv_rows[0]["counted_at"])
    assert_equal "02-MI-JAN-N", csv_rows[0]["station_external_id"]
    assert_equal "Jannowitzbruecke Nord", csv_rows[0]["station_name"]
    assert_equal "10", csv_rows[0]["count"]

    # Zero values must be kept as valid counts.
    zero_row = csv_rows.find { |row| row["count"] == "0" }
    assert_not_nil zero_row
  ensure
    File.delete(output_path) if output_path&.exist?
  end

  test "fails when requested year sheet is missing" do
    error = assert_raises(ArgumentError) do
      BikeCounts::XlsxNormalizer.call(
        input_path: fixture_path("bbcx_sample_source.xlsx"),
        year: 2024
      )
    end

    assert_includes error.message, "Jahresdatei 2024"
  end

  test "parses numeric xlsx values with trailing .0" do
    normalizer = BikeCounts::XlsxNormalizer.new(
      input_path: fixture_path("bbcx_sample_source.xlsx"),
      year: 2025
    )

    assert_equal 12, normalizer.send(:parse_integer, 12.0)
    assert_equal 8, normalizer.send(:parse_integer, "8.0")
    assert_equal 3, normalizer.send(:parse_integer, "3,0")
    assert_nil normalizer.send(:parse_integer, 2.5)
  end

  test "extracts station id from html-formatted header" do
    normalizer = BikeCounts::XlsxNormalizer.new(
      input_path: fixture_path("bbcx_sample_source.xlsx"),
      year: 2025
    )

    header = "<html><b>02-MI-JAN-N</b><b> 01.04.2015</b></html>"
    assert_equal "02-MI-JAN-N", normalizer.send(:extract_external_id, header)
  end

  test "resolves station metadata with SZ SK fallback" do
    normalizer = BikeCounts::XlsxNormalizer.new(
      input_path: fixture_path("bbcx_sample_source.xlsx"),
      year: 2025
    )

    metadata = {
      "17-SK-BRE-O" => { station_name: "Breitenbachplatz Ost" }
    }

    resolved = normalizer.send(:find_station_metadata, metadata, "17-SZ-BRE-O")
    assert_equal "Breitenbachplatz Ost", resolved[:station_name]
  end

  private

  def fixture_path(file_name)
    Rails.root.join("test", "fixtures", "files", file_name)
  end
end
