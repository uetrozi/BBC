# frozen_string_literal: true

require "csv"
require "zip"

module Weather
  class DwdImporter
    MISSING_VALUE_PATTERN = /\A-999(?:\.0+)?\z/.freeze
    PRODUCT_FILE_PATTERN = /produkt_klima_tag_.*\.txt\z/i
    STATION_METADATA_PATTERN = /Metadaten_Stationsname_Betreibername_.*\.txt\z/i

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
      @pending_rows = []
      @station = nil
    end

    def call
      validate_input_file!
      dwd_source = read_dwd_source

      CSV.parse(
        dwd_source[:product_content],
        col_sep: ";",
        headers: true,
        header_converters: ->(header) { header.to_s.strip }
      ) do |row|
        @result.rows_read += 1
        import_row(row, @result.rows_read + 1, dwd_source[:station_name])
      end

      flush_pending_rows
      @result
    rescue CSV::MalformedCSVError, Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
      raise ArgumentError, "DWD file is malformed or has invalid encoding: #{e.message}"
    end

    private

    def validate_input_file!
      raise ArgumentError, "Import file does not exist." unless @file_path.file?
    end

    def read_dwd_source
      if @file_path.extname.downcase == ".zip"
        read_from_zip
      else
        read_from_plain_text
      end
    end

    def read_from_zip
      product_content = nil
      station_name = nil

      Zip::File.open(@file_path) do |archive|
        product_entry = find_zip_entry(archive, PRODUCT_FILE_PATTERN)
        raise ArgumentError, "No DWD product file found in ZIP archive." if product_entry.nil?

        product_content = force_utf8(product_entry.get_input_stream.read)

        station_metadata_entry = find_zip_entry(archive, STATION_METADATA_PATTERN)
        station_name = parse_station_name(station_metadata_entry.get_input_stream.read) if station_metadata_entry
      end

      {
        product_content: product_content,
        station_name: station_name
      }
    end

    def find_zip_entry(archive, pattern)
      archive.entries.find { |entry| File.basename(entry.name).match?(pattern) }
    end

    def read_from_plain_text
      product_content = force_utf8(File.read(@file_path, mode: "rb"))

      station_metadata_file = Dir[@file_path.dirname.join("Metadaten_Stationsname_Betreibername_*.txt").to_s].first
      station_name = station_metadata_file ? parse_station_name(File.read(station_metadata_file, mode: "rb")) : nil

      {
        product_content: product_content,
        station_name: station_name
      }
    end

    def force_utf8(content)
      content.encode(Encoding::UTF_8, Encoding::ISO_8859_1, invalid: :replace, undef: :replace, replace: "")
    end

    def parse_station_name(content)
      csv = CSV.parse(force_utf8(content), col_sep: ";", headers: true)
      row = csv.find { |line| line["Stationsname"].present? }
      row&.[]("Stationsname")&.strip
    end

    def import_row(row, line_number, station_name_from_metadata)
      station_external_id = normalize_station_external_id(row["STATIONS_ID"])
      observed_on = parse_observed_on(row["MESS_DATUM"])
      mean_temperature = parse_measurement(row["TMK"])
      precipitation = parse_measurement(row["RSK"], non_negative: true)

      errors = []
      errors << "STATIONS_ID is invalid or missing" if station_external_id.blank?
      errors << "MESS_DATUM is invalid or missing" if observed_on.blank?
      errors << "TMK/RSK missing for row" if mean_temperature.nil? && precipitation.nil?

      if errors.any?
        register_error(line_number, errors)
        return
      end

      station = find_or_create_station(station_external_id, station_name_from_metadata)
      @pending_rows << build_row_hash(
        station_id: station.id,
        observed_on: observed_on,
        mean_temperature: mean_temperature,
        precipitation: precipitation
      )
    rescue StandardError => e
      register_error(line_number, [ e.message ])
    end

    def flush_pending_rows
      return if @pending_rows.empty?

      result = WeatherObservation.insert_all(
        @pending_rows,
        unique_by: %i[weather_station_id observed_on]
      )

      inserted_count = result.rows.length
      attempted_count = @pending_rows.length
      @result.imported_rows += inserted_count
      @result.skipped_duplicates += attempted_count - inserted_count
      @pending_rows.clear
    end

    def normalize_station_external_id(value)
      return nil if value.blank?

      Integer(value).to_s.rjust(5, "0")
    rescue ArgumentError
      nil
    end

    def parse_observed_on(value)
      return nil if value.blank?

      Date.strptime(value.to_s.strip, "%Y%m%d")
    rescue ArgumentError
      nil
    end

    def parse_measurement(value, non_negative: false)
      return nil if value.blank?

      normalized = value.to_s.strip.tr(",", ".")
      return nil if normalized.match?(MISSING_VALUE_PATTERN)

      decimal_value = BigDecimal(normalized)
      return nil if non_negative && decimal_value.negative?

      decimal_value
    rescue ArgumentError
      nil
    end

    def find_or_create_station(external_id, station_name_from_metadata)
      return @station if @station&.external_id == external_id

      @station = WeatherStation.find_or_initialize_by(external_id: external_id)
      station_name = station_name_from_metadata.presence || @station.name.presence
      raise ArgumentError, "Station name is missing for STATIONS_ID #{external_id}." if station_name.blank?

      @station.name = station_name
      @station.save!
      @station
    end

    def build_row_hash(station_id:, observed_on:, mean_temperature:, precipitation:)
      now = Time.current
      {
        weather_station_id: station_id,
        observed_on: observed_on,
        mean_temperature: mean_temperature,
        precipitation: precipitation,
        created_at: now,
        updated_at: now
      }
    end

    def register_error(line_number, messages)
      @result.invalid_rows += 1
      @result.errors << { line: line_number, messages: messages }
    end
  end
end
