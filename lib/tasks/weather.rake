# frozen_string_literal: true

namespace :weather do
  desc "Import DWD daily weather observations from local file"
  task :import, [ :file_path ] => :environment do |_, args|
    file_path = args[:file_path]

    if file_path.blank?
      puts 'Usage: bin/rails "weather:import[data/raw/tageswerte_KL_00433_19480101_20251231_hist.zip]"'
      exit(1)
    end

    result = Weather::DwdImporter.call(file_path)

    puts "Weather import finished"
    puts "Rows read: #{result.rows_read}"
    puts "Imported rows: #{result.imported_rows}"
    puts "Skipped duplicates: #{result.skipped_duplicates}"
    puts "Invalid rows: #{result.invalid_rows}"

    if result.errors.any?
      puts "\nErrors:"
      result.errors.first(50).each do |error|
        puts "- DWD line #{error[:line]}: #{error[:messages].join('; ')}"
      end
      puts "... (#{result.errors.size} total errors)" if result.errors.size > 50
    end
  rescue StandardError => e
    warn "Weather import failed: #{safe_error_message(e.message)}"
    exit(1)
  end

  def safe_error_message(message)
    message.to_s.gsub(%r{/[^\s]+}, "[path]")
  end
end
