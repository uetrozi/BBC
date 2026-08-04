# frozen_string_literal: true

module BikeCounts
  class FilterQuery
    Result = Struct.new(:scope, :errors, :field_errors, :unknown_station_id, keyword_init: true)

    def initialize(scope:, params:)
      @scope = scope
      @params = params
    end

    def call
      errors = []
      field_errors = {}
      filtered_scope = @scope
      unknown_station_id = false

      station_filter = parse_station_id(@params[:station_id], errors, field_errors)
      if station_filter[:status] == :ok
        filtered_scope = filtered_scope.where(counting_station_id: station_filter[:id])
      elsif station_filter[:status] == :unknown
        unknown_station_id = true
        filtered_scope = filtered_scope.none
      elsif station_filter[:status] == :invalid
        filtered_scope = filtered_scope.none
      end

      start_date = parse_date(@params[:from], "Start date", :from, errors, field_errors)
      end_date = parse_date(@params[:to], "End date", :to, errors, field_errors)

      if start_date.present? && end_date.present? && end_date < start_date
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
        unknown_station_id: unknown_station_id
      )
    end

    private

    def parse_station_id(raw_value, errors, field_errors)
      return { status: :none } if raw_value.blank?

      station_id = Integer(raw_value)
      if station_id <= 0
        add_error(errors, field_errors, :station_id, "Counting station ID must be a positive integer.")
        return { status: :invalid }
      end

      return { status: :ok, id: station_id } if CountingStation.exists?(station_id)

      add_error(errors, field_errors, :station_id, "Unknown counting station ID: #{station_id}.")
      { status: :unknown, id: station_id }
    rescue ArgumentError
      add_error(errors, field_errors, :station_id, "Counting station ID must be a positive integer.")
      { status: :invalid }
    end

    def parse_date(raw_value, label, field, errors, field_errors)
      return nil if raw_value.blank?

      Date.iso8601(raw_value)
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
