# frozen_string_literal: true

namespace :bbcx do
  desc "Normalize official Berlin XLSX year sheet to BBC-X CSV format"
  task :normalize_xlsx, [ :xlsx_path, :year, :output_csv ] => :environment do |_, args|
    xlsx_path = args[:xlsx_path]
    year = args[:year]
    output_csv = args[:output_csv]

    if xlsx_path.blank? || year.blank?
      puts "Usage: bin/rails \"bbcx:normalize_xlsx[data/raw/gesamtdatei-stundenwerte.xlsx,2025,data/raw/bbcx_normalized_2025.csv]\""
      exit(1)
    end

    result = BikeCounts::XlsxNormalizer.call(
      input_path: xlsx_path,
      year: year,
      output_path: output_csv
    )

    puts "BBC-X normalization finished"
    puts "Year: #{result.year}"
    puts "Input rows read: #{result.rows_read}"
    puts "Rows written: #{result.rows_written}"
    puts "Rows skipped: #{result.rows_skipped}"
    puts "Output: #{result.output_path}"

    if result.errors.any?
      puts "\nWarnings:"
      result.errors.first(30).each do |error|
        puts "- Sheet row #{error[:row]}: #{error[:messages].join('; ')}"
      end
      puts "... (#{result.errors.size} total warnings)" if result.errors.size > 30
    end
  rescue StandardError => e
    warn "Normalization failed: #{safe_error_message(e.message)}"
    exit(1)
  end

  desc "Import bike counts from a normalized CSV file"
  task :import, [ :file_path ] => :environment do |_, args|
    file_path = args[:file_path]

    if file_path.blank?
      puts "Usage: bin/rails \"bbcx:import[data/raw/your_file.csv]\""
      exit(1)
    end

    runner_result = BikeCounts::ImportRunner.call(file_path)
    result = runner_result.import_result
    import_batch = runner_result.import_batch

    puts "BBC-X import finished"
    puts "Import batch ID: #{import_batch.id}"
    puts "Source file: #{import_batch.filename}"
    puts "Import status: #{import_batch.status}"
    puts "Rows read: #{result.rows_read}"
    puts "Imported rows: #{result.imported_rows}"
    puts "Skipped duplicates: #{result.skipped_duplicates}"
    puts "Invalid rows: #{result.invalid_rows}"

    if result.errors.any?
      puts "\nErrors:"
      result.errors.each do |error|
        puts "- CSV line #{error[:line]}: #{error[:messages].join('; ')}"
      end
    end
  rescue StandardError => e
    warn "Import failed: #{safe_error_message(e.message)}"
    exit(1)
  end

  desc "Normalize XLSX year sheet and import resulting CSV in one command"
  task :normalize_and_import, [ :xlsx_path, :year, :output_csv ] => :environment do |_, args|
    xlsx_path = args[:xlsx_path]
    year = args[:year]
    output_csv = args[:output_csv]

    if xlsx_path.blank? || year.blank?
      puts "Usage: bin/rails \"bbcx:normalize_and_import[data/raw/gesamtdatei-stundenwerte.xlsx,2025,data/raw/bbcx_normalized_2025.csv]\""
      exit(1)
    end

    normalization_result = BikeCounts::XlsxNormalizer.call(
      input_path: xlsx_path,
      year: year,
      output_path: output_csv
    )
    import_runner_result = BikeCounts::ImportRunner.call(normalization_result.output_path)
    import_result = import_runner_result.import_result
    import_batch = import_runner_result.import_batch

    puts "BBC-X normalize+import finished"
    puts "Normalization rows written: #{normalization_result.rows_written}"
    puts "Import batch ID: #{import_batch.id}"
    puts "Import status: #{import_batch.status}"
    puts "Imported rows: #{import_result.imported_rows}"
    puts "Skipped duplicates: #{import_result.skipped_duplicates}"
    puts "Invalid rows: #{import_result.invalid_rows}"
    puts "Final CSV: #{normalization_result.output_path}"
  rescue StandardError => e
    warn "Normalize+import failed: #{safe_error_message(e.message)}"
    exit(1)
  end

  def safe_error_message(message)
    message.to_s.gsub(%r{/[^\s]+}, "[path]")
  end
end
