# frozen_string_literal: true

module BikeCounts
  class Statistics
    Result = Struct.new(
      :total_bikes,
      :average_per_day,
      :evaluated_days,
      :strongest_day,
      :daily_series,
      keyword_init: true
    )

    def initialize(scope:)
      @scope = scope
    end

    def call
      daily_totals = daily_totals_relation.sum(:count)
      evaluated_days = daily_totals.size
      total_bikes = daily_totals.values.sum
      strongest_day = strongest_day(daily_totals)

      Result.new(
        total_bikes: total_bikes,
        average_per_day: average_per_day(total_bikes, evaluated_days),
        evaluated_days: evaluated_days,
        strongest_day: strongest_day,
        daily_series: daily_series(daily_totals)
      )
    end

    private

    def base_scope
      @scope.except(:includes, :preload, :eager_load, :order, :limit, :offset, :select)
    end

    def daily_totals_relation
      base_scope
        .group("DATE(bike_counts.counted_at)")
    end

    def average_per_day(total_bikes, evaluated_days)
      return nil if evaluated_days.zero?

      BigDecimal(total_bikes.to_s) / BigDecimal(evaluated_days.to_s)
    end

    def strongest_day(daily_totals)
      strongest = daily_totals.sort_by { |date, count| [ -count, parse_date(date) ] }.first
      return nil if strongest.nil?

      {
        date: parse_date(strongest.first),
        count: strongest.last
      }
    end

    def daily_series(daily_totals)
      daily_totals
        .sort_by { |date, _count| parse_date(date) }
        .map do |date, count|
        {
          date: parse_date(date).iso8601,
          count: count.to_i
        }
        end
    end

    def parse_date(value)
      value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    end
  end
end
