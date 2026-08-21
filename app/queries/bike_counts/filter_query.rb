# frozen_string_literal: true

module BikeCounts
  class FilterQuery
    MAX_COMPARISON_STATIONS = 5
    ALLOWED_FROM_DATE = Date.iso8601("2025-01-01")
    ALLOWED_TO_DATE = Date.iso8601("2025-12-31")

    Result = Struct.new(
      :scope,
      :errors,
      :field_errors,
      :unknown_station_ids,
      :selected_station_ids,
      keyword_init: true
    )

    def initialize(scope:, params:)
      @scope = scope
      @params = params
    end

    def call
      errors = []
      field_errors = {}
      filtered_scope = @scope
      unknown_station_ids = []
      selected_station_ids = []

      station_filter = parse_station_ids(@params[:station_ids], errors, field_errors)
      if station_filter[:status] == :ok
        selected_station_ids = station_filter[:ids]
        filtered_scope = filtered_scope.where(counting_station_id: selected_station_ids)
      elsif station_filter[:status] == :unknown
        unknown_station_ids = station_filter[:ids]
        filtered_scope = filtered_scope.none
      elsif station_filter[:status] == :invalid
        filtered_scope = filtered_scope.none
      end

      start_date = parse_date(@params[:from], "Start date", :from, errors, field_errors)
      end_date = parse_date(@params[:to], "End date", :to, errors, field_errors)

      if field_errors[:from].present? || field_errors[:to].present?
        filtered_scope = filtered_scope.none
      elsif start_date.present? && end_date.present? && end_date < start_date
        add_error(
          errors,
          field_errors,
          :to,
          "End date must be on or after start date."
        )
        filtered_scope = filtered_scope.none
      else
        filtered_scope = filtered_scope.where("counted_at >= ?", start_date.beginning_of_day) if start_date.present?
        filtered_scope = filtered_scope.where("counted_at <= ?", end_date.end_of_day) if end_date.present?
      end

      Result.new(
        scope: filtered_scope,
        errors: errors,
        field_errors: field_errors,
        unknown_station_ids: unknown_station_ids,
        selected_station_ids: selected_station_ids
      )
    end

    private

    def parse_station_ids(raw_values, errors, field_errors)
      station_ids = Array(raw_values).reject(&:blank?).map(&:to_s).uniq
      return { status: :none } if station_ids.empty?

      if station_ids.size > MAX_COMPARISON_STATIONS
        add_error(
          errors,
          field_errors,
          :station_ids,
          "Please select at most #{MAX_COMPARISON_STATIONS} counting stations for comparison."
        )
        return { status: :invalid }
      end

      parsed_ids = station_ids.map { |value| Integer(value) }
      if parsed_ids.any? { |id| id <= 0 }
        add_error_for_invalid_station_ids(errors, field_errors, station_ids)
        return { status: :invalid }
      end

      known_ids = CountingStation.where(id: parsed_ids).pluck(:id)
      unknown_ids = parsed_ids - known_ids
      if unknown_ids.any?
        add_error_for_unknown_station_ids(errors, field_errors, unknown_ids)
        return { status: :unknown, ids: unknown_ids }
      end

      { status: :ok, ids: parsed_ids }
    rescue ArgumentError
      add_error_for_invalid_station_ids(errors, field_errors, station_ids)
      { status: :invalid }
    end

    def add_error_for_invalid_station_ids(errors, field_errors, station_ids)
      message = if station_ids.size == 1
        "Counting station ID must be a positive integer."
      else
        "Counting station IDs must be positive integers."
      end

      add_error(errors, field_errors, :station_ids, message)
    end

    def add_error_for_unknown_station_ids(errors, field_errors, unknown_ids)
      message = if unknown_ids.size == 1
        "Unknown counting station ID: #{unknown_ids.first}."
      else
        "Unknown counting station IDs: #{unknown_ids.join(', ')}."
      end

      add_error(errors, field_errors, :station_ids, message)
    end

    def parse_date(raw_value, label, field, errors, field_errors)
      return nil if raw_value.blank?

      parsed_date = Date.iso8601(raw_value)
      if parsed_date < ALLOWED_FROM_DATE || parsed_date > ALLOWED_TO_DATE
        add_error(
          errors,
          field_errors,
          field,
          "#{label} must be between #{ALLOWED_FROM_DATE.iso8601} and #{ALLOWED_TO_DATE.iso8601}."
        )
        return nil
      end

      parsed_date
    rescue ArgumentError
      add_error(errors, field_errors, field, "#{label} is invalid: #{raw_value}.")
      nil
    end

    def add_error(errors, field_errors, field, message)
      errors << message
      field_errors[field] ||= []
      field_errors[field] << message
    end
  end
end
