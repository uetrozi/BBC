# frozen_string_literal: true

require "csv"
require "roo"

module BikeCounts
  class XlsxNormalizer
    Result = Struct.new(
      :rows_read,
      :rows_written,
      :rows_skipped,
      :year,
      :output_path,
      :errors,
      keyword_init: true
    )

    def self.call(input_path:, year:, output_path: nil)
      new(input_path: input_path, year: year, output_path: output_path).call
    end

    def initialize(input_path:, year:, output_path: nil)
      @input_path = Pathname.new(input_path)
      @year = Integer(year)
      @sheet_name = "Jahresdatei #{@year}"
      @output_path = Pathname.new(output_path || default_output_path)
      @result = Result.new(
        rows_read: 0,
        rows_written: 0,
        rows_skipped: 0,
        year: @year,
        output_path: @output_path.to_s,
        errors: []
      )
    end

    def call
      validate_input_file!
      workbook = Roo::Spreadsheet.open(@input_path.to_s)
      ensure_sheet_exists!(workbook)

      station_metadata = read_station_metadata(workbook)
      station_headers = read_station_headers(workbook)

      FileUtils.mkdir_p(@output_path.dirname)
      write_normalized_csv(workbook, station_headers, station_metadata)

      @result
    end

    private

    def validate_input_file!
      raise ArgumentError, "File not found: #{@input_path}" unless @input_path.file?
    end

    def ensure_sheet_exists!(workbook)
      return if workbook.sheets.include?(@sheet_name)

      raise ArgumentError, "Sheet '#{@sheet_name}' not found in #{@input_path}"
    end

    def read_station_metadata(workbook)
      workbook.default_sheet = "Standortdaten"
      metadata = {}

      (2..workbook.last_row).each do |row_index|
        external_id = normalize_external_id(workbook.cell(row_index, 1))
        next if external_id.blank?

        metadata[external_id] = {
          station_name: value_or_nil(workbook.cell(row_index, 2)),
          latitude: value_or_nil(workbook.cell(row_index, 3)),
          longitude: value_or_nil(workbook.cell(row_index, 4)),
          installed_at: parse_date(workbook.cell(row_index, 5))
        }
      end

      metadata
    end

    def read_station_headers(workbook)
      workbook.default_sheet = @sheet_name
      headers = []

      (2..workbook.last_column).each do |column_index|
        raw_header = value_or_nil(workbook.cell(1, column_index))
        next if raw_header.blank?

        external_id = extract_external_id(raw_header)
        next if external_id.blank?

        headers << { column_index: column_index, external_id: external_id }
      end

      headers
    end

    def write_normalized_csv(workbook, station_headers, station_metadata)
      workbook.default_sheet = @sheet_name

      CSV.open(@output_path, "w", write_headers: true, headers: normalized_headers) do |csv|
        (2..workbook.last_row).each do |row_index|
          timestamp = parse_datetime(workbook.cell(row_index, 1))
          @result.rows_read += 1

          if timestamp.nil?
            @result.rows_skipped += station_headers.length
            @result.errors << { row: row_index, messages: [ "missing timestamp" ] }
            next
          end

          station_headers.each do |station_header|
            count = parse_integer(workbook.cell(row_index, station_header[:column_index]))

            if count.nil?
              @result.rows_skipped += 1
              next
            end

            external_id = station_header[:external_id]
            metadata = find_station_metadata(station_metadata, external_id)

            if metadata.nil? || metadata[:station_name].blank?
              @result.rows_skipped += 1
              @result.errors << {
                row: row_index,
                messages: [ "missing station metadata for #{external_id}" ]
              }
              next
            end

            csv << [
              timestamp.iso8601,
              external_id,
              metadata[:station_name],
              count,
              metadata[:latitude],
              metadata[:longitude],
              metadata[:installed_at]
            ]
            @result.rows_written += 1
          end
        end
      end
    end

    def normalized_headers
      [
        "counted_at",
        "station_external_id",
        "station_name",
        "count",
        "latitude",
        "longitude",
        "installed_at"
      ]
    end

    def default_output_path
      Rails.root.join("data", "raw", "bbcx_normalized_#{@year}.csv")
    end

    def extract_external_id(header)
      normalize_external_id(header)
    end

    def find_station_metadata(station_metadata, external_id)
      return station_metadata[external_id] if station_metadata.key?(external_id)

      alternate_external_ids(external_id).each do |alternate_id|
        return station_metadata[alternate_id] if station_metadata.key?(alternate_id)
      end

      nil
    end

    def alternate_external_ids(external_id)
      [
        external_id.gsub("-SZ-", "-SK-"),
        external_id.gsub("-SK-", "-SZ-")
      ].uniq - [ external_id ]
    end

    def normalize_external_id(value)
      cleaned = value.to_s.gsub(/<[^>]*>/, " ").gsub(/\s+/, " ").strip
      token = cleaned.split(" ").first
      token&.upcase
    end

    def parse_datetime(value)
      return nil if value.blank?

      if value.respond_to?(:year) && value.respond_to?(:hour)
        return Time.zone.local(
          value.year,
          value.month,
          value.day,
          value.hour,
          value.min,
          value.sec
        )
      end

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def parse_date(value)
      return nil if value.blank?

      if value.respond_to?(:to_date)
        value.to_date.iso8601
      else
        Date.parse(value.to_s).iso8601
      end
    rescue ArgumentError
      nil
    end

    def parse_integer(value)
      return nil if value.blank?

      if value.is_a?(Numeric)
        return nil if value.negative?

        integer = value.to_i
        return integer if value == integer

        return nil
      end

      normalized = value.to_s.strip.tr(",", ".")
      return nil unless normalized.match?(/\A\d+(?:\.0+)?\z/)

      normalized.to_i
    end

    def value_or_nil(value)
      return nil if value.nil?

      value.to_s.strip.presence
    end
  end
end
