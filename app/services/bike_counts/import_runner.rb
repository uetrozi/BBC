# frozen_string_literal: true

module BikeCounts
  class ImportRunner
    Result = Struct.new(:import_result, :import_batch, keyword_init: true)

    def self.call(file_path)
      new(file_path).call
    end

    def initialize(file_path)
      @file_path = Pathname.new(file_path)
    end

    def call
      import_batch = ImportBatch.create!(
        filename: @file_path.basename.to_s,
        imported_at: Time.current,
        status: "running"
      )

      import_result = CsvImporter.call(@file_path)
      import_batch.update!(
        rows_read: import_result.rows_read,
        imported_rows: import_result.imported_rows,
        skipped_duplicates: import_result.skipped_duplicates,
        invalid_rows: import_result.invalid_rows,
        status: import_result.invalid_rows.positive? ? "completed_with_errors" : "completed"
      )

      Result.new(import_result: import_result, import_batch: import_batch)
    rescue StandardError
      import_batch&.update!(status: "failed")
      raise
    end
  end
end
