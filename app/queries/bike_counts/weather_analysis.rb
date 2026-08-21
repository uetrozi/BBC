# frozen_string_literal: true

module BikeCounts
  class WeatherAnalysis
    Row = Struct.new(
      :date,
      :bike_count,
      :mean_temperature,
      :precipitation,
      :bvg_strike,
      :bvg_strike_label,
      :bvg_strike_note,
      keyword_init: true
    )

    def initialize(scope:, weather_station:)
      @scope = scope
      @weather_station = weather_station
    end

    def call
      daily_totals = daily_bike_totals
      return [] if daily_totals.empty?

      weather_by_date = weather_by_date_for(daily_totals.keys)

      daily_totals
        .sort_by { |date, _count| parse_date(date) }
        .map do |date, bike_count|
          parsed_date = parse_date(date)
          weather = weather_by_date[parsed_date]
          strike_event = ExternalEvents::BvgStrikeDays.event_for(parsed_date)
          Row.new(
            date: parsed_date.iso8601,
            bike_count: bike_count.to_i,
            mean_temperature: weather&.mean_temperature&.to_f,
            precipitation: weather&.precipitation&.to_f,
            bvg_strike: strike_event.present?,
            bvg_strike_label: strike_event&.dig(:label),
            bvg_strike_note: strike_event&.dig(:note)
          )
        end
    end

    private

    def base_scope
      @scope.except(:includes, :preload, :eager_load, :order, :limit, :offset, :select)
    end

    def daily_bike_totals
      base_scope.group("DATE(bike_counts.counted_at)").sum(:count)
    end

    def weather_by_date_for(dates)
      observed_range = parse_date(dates.min)..parse_date(dates.max)
      WeatherObservation
        .where(weather_station: @weather_station, observed_on: observed_range)
        .index_by(&:observed_on)
    end

    def parse_date(value)
      value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    end
  end
end
