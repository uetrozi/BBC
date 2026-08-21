# frozen_string_literal: true

module BikeCounts
  class WeatherCorrelationAnalysis
    Result = Struct.new(
      :temperature_points,
      :precipitation_points,
      :temperature_heatmap,
      :precipitation_heatmap,
      :temperature_correlation,
      :precipitation_correlation,
      keyword_init: true
    )

    def self.empty_result
      Result.new(
        temperature_points: [],
        precipitation_points: [],
        temperature_heatmap: BikeCounts::WeatherHeatmap::Result.new(x_labels: [], y_labels: [], cells: [], max_days: 0),
        precipitation_heatmap: BikeCounts::WeatherHeatmap::Result.new(x_labels: [], y_labels: [], cells: [], max_days: 0),
        temperature_correlation: nil,
        precipitation_correlation: nil
      )
    end

    def initialize(scope:, weather_station:)
      @scope = scope
      @weather_station = weather_station
    end

    def call
      rows = BikeCounts::WeatherAnalysis.new(
        scope: @scope,
        weather_station: @weather_station
      ).call

      heatmap = BikeCounts::WeatherHeatmap.new(rows: rows)
      temperature_points = build_points(rows, :mean_temperature)
      precipitation_points = build_points(rows, :precipitation)

      Result.new(
        temperature_points: temperature_points,
        precipitation_points: precipitation_points,
        temperature_heatmap: heatmap.temperature_result,
        precipitation_heatmap: heatmap.precipitation_result,
        temperature_correlation: correlation_for(temperature_points),
        precipitation_correlation: correlation_for(precipitation_points)
      )
    end

    private

    def build_points(rows, weather_metric)
      rows.filter_map do |row|
        weather_value = row.public_send(weather_metric)
        next if weather_value.nil?

        {
          x: weather_value.to_f,
          y: row.bike_count.to_i,
          date: row.date,
          mean_temperature: row.mean_temperature&.to_f,
          precipitation: row.precipitation&.to_f,
          bvg_strike: row.bvg_strike,
          bvg_strike_label: row.bvg_strike_label,
          bvg_strike_note: row.bvg_strike_note
        }
      end
    end

    def correlation_for(points)
      ::Statistics::PearsonCorrelation.call(
        xs: points.map { |point| point[:x] },
        ys: points.map { |point| point[:y] }
      )
    end
  end
end
