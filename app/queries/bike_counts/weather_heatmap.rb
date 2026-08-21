# frozen_string_literal: true

module BikeCounts
  class WeatherHeatmap
    BIKE_BIN_SIZE = 1000

    TEMPERATURE_BINS = [
      { key: :below_zero, label: "unter 0 °C" },
      { key: :zero_to_five, label: "0 bis <5 °C" },
      { key: :five_to_ten, label: "5 bis <10 °C" },
      { key: :ten_to_fifteen, label: "10 bis <15 °C" },
      { key: :fifteen_to_twenty, label: "15 bis <20 °C" },
      { key: :twenty_to_twenty_five, label: "20 bis <25 °C" },
      { key: :twenty_five_to_thirty, label: "25 bis <30 °C" },
      { key: :thirty_plus, label: "ab 30 °C" }
    ].freeze

    PRECIPITATION_BINS = [
      { key: :zero_mm, label: "0 mm" },
      { key: :gt_zero_to_one, label: ">0 bis 1 mm" },
      { key: :gt_one_to_three, label: ">1 bis 3 mm" },
      { key: :gt_three_to_five, label: ">3 bis 5 mm" },
      { key: :gt_five_to_ten, label: ">5 bis 10 mm" },
      { key: :gt_ten_to_twenty, label: ">10 bis 20 mm" },
      { key: :gt_twenty, label: "über 20 mm" }
    ].freeze

    Result = Struct.new(
      :x_labels,
      :y_labels,
      :cells,
      :max_days,
      keyword_init: true
    )

    def initialize(rows:)
      @rows = rows
    end

    def temperature_result
      build_result(
        weather_value_extractor: ->(row) { row.mean_temperature },
        weather_bin_resolver: method(:temperature_bin_for),
        weather_bin_order: TEMPERATURE_BINS.map { |bin| bin[:key] }
      )
    end

    def precipitation_result
      build_result(
        weather_value_extractor: ->(row) { row.precipitation },
        weather_bin_resolver: method(:precipitation_bin_for),
        weather_bin_order: PRECIPITATION_BINS.map { |bin| bin[:key] }
      )
    end

    private

    def build_result(weather_value_extractor:, weather_bin_resolver:, weather_bin_order:)
      y_labels = bike_bin_labels
      return empty_result if y_labels.empty?

      grouped_days = Hash.new(0)
      used_weather_bins = {}

      @rows.each do |row|
        weather_value = weather_value_extractor.call(row)
        next if weather_value.nil?

        weather_bin = weather_bin_resolver.call(weather_value.to_f)
        next if weather_bin.nil?

        bike_bin_index = bike_bin_index_for(row.bike_count.to_i)
        key = [ weather_bin[:key], bike_bin_index ]
        grouped_days[key] += 1
        used_weather_bins[weather_bin[:key]] = weather_bin[:label]
      end

      ordered_weather_keys = weather_bin_order.select { |key| used_weather_bins.key?(key) }
      x_labels = ordered_weather_keys.map { |key| used_weather_bins.fetch(key) }
      x_indexes = ordered_weather_keys.each_with_index.to_h

      cells = grouped_days.map do |(weather_key, bike_bin_index), days|
        x_index = x_indexes[weather_key]
        next if x_index.nil?

        {
          x: x_index,
          y: bike_bin_index,
          v: days,
          weather_bin: used_weather_bins.fetch(weather_key),
          bike_bin: y_labels.fetch(bike_bin_index),
          days: days
        }
      end.compact

      Result.new(
        x_labels: x_labels,
        y_labels: y_labels,
        cells: cells,
        max_days: cells.map { |cell| cell[:days] }.max.to_i
      )
    end

    def bike_bin_labels
      max_bike_count = @rows.map { |row| row.bike_count.to_i }.max
      return [] if max_bike_count.nil?

      max_bin_index = max_bike_count / BIKE_BIN_SIZE
      (0..max_bin_index).map do |index|
        lower = index * BIKE_BIN_SIZE
        upper = lower + BIKE_BIN_SIZE - 1
        "#{format_integer(lower)}–#{format_integer(upper)}"
      end
    end

    def bike_bin_index_for(bike_count)
      bike_count / BIKE_BIN_SIZE
    end

    def temperature_bin_for(value)
      return TEMPERATURE_BINS[0] if value < 0
      return TEMPERATURE_BINS[1] if value < 5
      return TEMPERATURE_BINS[2] if value < 10
      return TEMPERATURE_BINS[3] if value < 15
      return TEMPERATURE_BINS[4] if value < 20
      return TEMPERATURE_BINS[5] if value < 25
      return TEMPERATURE_BINS[6] if value < 30

      TEMPERATURE_BINS[7]
    end

    def precipitation_bin_for(value)
      return PRECIPITATION_BINS[0] if value.zero?
      return PRECIPITATION_BINS[1] if value <= 1
      return PRECIPITATION_BINS[2] if value <= 3
      return PRECIPITATION_BINS[3] if value <= 5
      return PRECIPITATION_BINS[4] if value <= 10
      return PRECIPITATION_BINS[5] if value <= 20

      PRECIPITATION_BINS[6]
    end

    def format_integer(value)
      value.to_i.to_s.reverse.scan(/\d{1,3}/).join(".").reverse
    end

    def empty_result
      Result.new(x_labels: [], y_labels: [], cells: [], max_days: 0)
    end
  end
end
