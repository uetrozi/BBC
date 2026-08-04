require "test_helper"

class BikeCounts::ImportRunnerTest < ActiveSupport::TestCase
  setup do
    BikeCount.delete_all
    CountingStation.delete_all
    ImportBatch.delete_all
  end

  test "creates completed import batch for successful import" do
    result = BikeCounts::ImportRunner.call(fixture_path("bbcx_valid_import.csv"))

    assert_equal "completed", result.import_batch.status
    assert_equal "bbcx_valid_import.csv", result.import_batch.filename
    assert_equal 4, result.import_batch.rows_read
    assert_equal 4, result.import_batch.imported_rows
    assert_equal 0, result.import_batch.invalid_rows
  end

  test "creates completed_with_errors batch when rows are invalid" do
    result = BikeCounts::ImportRunner.call(fixture_path("bbcx_invalid_rows.csv"))

    assert_equal "completed_with_errors", result.import_batch.status
    assert_equal 3, result.import_batch.rows_read
    assert_equal 0, result.import_batch.imported_rows
    assert_equal 3, result.import_batch.invalid_rows
  end

  test "marks batch as failed when importer raises" do
    assert_raises(ArgumentError) do
      BikeCounts::ImportRunner.call("missing-file.csv")
    end

    batch = ImportBatch.order(:created_at).last
    assert_equal "missing-file.csv", batch.filename
    assert_equal "failed", batch.status
  end

  private

  def fixture_path(file_name)
    Rails.root.join("test", "fixtures", "files", file_name)
  end
end
