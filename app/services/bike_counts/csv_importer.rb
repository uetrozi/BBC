# frozen_string_literal: true

require "csv"

module BikeCounts
  class CsvImporter
    BATCH_SIZE = 5_000

    Result = Struct.new(
      :rows_read,
      :imported_rows,
      :skipped_duplicates,
      :invalid_rows,
      :errors,
      keyword_init: true
    )

    def self.call(file_path)
      new(file_path).call
    end

    def initialize(file_path)
      @file_path = Pathname.new(file_path)
      @result = Result.new(
        rows_read: 0,
        imported_rows: 0,
        skipped_duplicates: 0,
        invalid_rows: 0,
        errors: []
      )
      @station_id_cache = {}
      @pending_rows = []
    end

    def call
      validate_file!

      CSV.foreach(@file_path, headers: true, encoding: "bom|utf-8") do |row|
        @result.rows_read += 1
        import_row(row, @result.rows_read + 1)
        flush_pending_rows if @pending_rows.size >= BATCH_SIZE
      end

      flush_pending_rows

      @result
    rescue CSV::MalformedCSVError, ArgumentError => e
      raise ArgumentError, e.message
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      raise ArgumentError, "CSV encoding is invalid. Please provide UTF-8 encoded CSV content."
    end

    private

    def validate_file!
      raise ArgumentError, "Import file does not exist." unless @file_path.file?
      validate_utf8_encoding!

      required_headers = [
        "counted_at",
        "station_external_id",
        "station_name",
        "count"
      ]

      headers = CSV.open(@file_path, "r", &:readline)
      raise ArgumentError, "CSV file is empty." if headers.nil?
    rescue EOFError
      raise ArgumentError, "CSV file is empty."
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      raise ArgumentError, "CSV encoding is invalid. Please provide UTF-8 encoded CSV content."
    else
      missing_headers = required_headers - headers
      return if missing_headers.empty?

      raise ArgumentError, "CSV file is missing required headers: #{missing_headers.join(', ')}."
    end

    def validate_utf8_encoding!
      content = File.binread(@file_path).dup
      content.force_encoding(Encoding::UTF_8)
      return if content.valid_encoding?

      raise ArgumentError, "CSV encoding is invalid. Please provide UTF-8 encoded CSV content."
    end

    def import_row(row, csv_line_number)
      attributes = normalize_row(row)
      errors = validate_row(attributes)

      if errors.any?
        register_error(csv_line_number, errors)
        return
      end

      station_id = find_or_upsert_station_id(attributes)
      @pending_rows << build_row_hash(
        station_id,
        counted_at: attributes[:counted_at],
        count: attributes[:count]
      )
    rescue StandardError => e
      register_error(csv_line_number, [ e.message ])
    end

    def flush_pending_rows
      return if @pending_rows.empty?

      result = BikeCount.insert_all(
        @pending_rows,
        unique_by: :index_bike_counts_on_counting_station_id_and_counted_at
      )

      inserted_count = result.rows.length
      attempted_count = @pending_rows.length
      @result.imported_rows += inserted_count
      @result.skipped_duplicates += attempted_count - inserted_count
      @pending_rows.clear
    end

    def normalize_row(row)
      {
        station_external_id: value_or_nil(row["station_external_id"]),
        station_name: value_or_nil(row["station_name"]),
        counted_at: parse_datetime(value_or_nil(row["counted_at"])),
        count: parse_integer(value_or_nil(row["count"])),
        latitude: parse_decimal(value_or_nil(row["latitude"])),
        longitude: parse_decimal(value_or_nil(row["longitude"])),
        installed_at: parse_date(value_or_nil(row["installed_at"]))
      }
    end

    def validate_row(attributes)
      errors = []
      errors << "station_external_id is missing" if attributes[:station_external_id].blank?
      errors << "station_name is missing" if attributes[:station_name].blank?
      errors << "counted_at is invalid or missing" if attributes[:counted_at].blank?
      errors << "count must be an integer >= 0" if attributes[:count].nil? || attributes[:count].negative?
      errors
    end

    def find_or_upsert_station_id(attributes)
      external_id = attributes[:station_external_id]
      return @station_id_cache[external_id] if @station_id_cache.key?(external_id)

      station = CountingStation.find_or_initialize_by(external_id: external_id)
      station.name = attributes[:station_name] if station.name.blank?
      station.latitude = attributes[:latitude] if station.latitude.blank? && attributes[:latitude].present?
      station.longitude = attributes[:longitude] if station.longitude.blank? && attributes[:longitude].present?
      station.installed_at = attributes[:installed_at] if station.installed_at.blank? && attributes[:installed_at].present?
      station.save!
      @station_id_cache[external_id] = station.id
    end

    def build_row_hash(station_id, counted_at:, count:)
      now = Time.current
      {
        counting_station_id: station_id,
        counted_at: counted_at,
        count: count,
        created_at: now,
        updated_at: now
      }
    end

    def parse_datetime(value)
      return nil if value.blank?

      Time.zone.parse(value)&.to_datetime
    rescue ArgumentError
      nil
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value)
    rescue ArgumentError
      nil
    end

    def parse_integer(value)
      return nil if value.blank?

      Integer(value)
    rescue ArgumentError
      nil
    end

    def parse_decimal(value)
      return nil if value.blank?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def value_or_nil(value)
      value.to_s.strip.presence
    end

    def register_error(csv_line_number, messages)
      @result.invalid_rows += 1
      @result.errors << {
        line: csv_line_number,
        messages: messages
      }
    end
  end
end
