require "test_helper"

class ImportBatchTest < ActiveSupport::TestCase
  test "requires filename imported_at and valid status" do
    batch = ImportBatch.new

    assert_not batch.valid?
    assert_includes batch.errors[:filename], "can't be blank"
    assert_includes batch.errors[:imported_at], "can't be blank"
    assert_includes batch.errors[:status], "can't be blank"
  end

  test "accepts known statuses" do
    ImportBatch::STATUSES.each do |status|
      batch = ImportBatch.new(filename: "data.csv", imported_at: Time.current, status: status)
      assert batch.valid?, "Expected status #{status} to be valid"
    end
  end
end
