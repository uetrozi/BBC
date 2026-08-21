# frozen_string_literal: true

require "yaml"

module ExternalEvents
  module BvgStrikeDays
    module_function

    def strike_day?(date)
      event_for(date).present?
    end

    def event_for(date)
      parsed = parse_date(date)
      return nil if parsed.nil?

      events_by_date[parsed]
    end

    def events
      @events ||= load_events.freeze
    end

    def reset_cache!
      @events = nil
      @events_by_date = nil
      @config_data = nil
    end

    def source
      config_data.fetch("source")
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return Date.iso8601(value) if value.is_a?(String)

      nil
    rescue ArgumentError
      nil
    end

    def events_by_date
      @events_by_date ||= events.index_by { |event| event.fetch(:date) }.freeze
    end

    def load_events
      config_data.fetch("events").map do |event|
        {
          date: Date.iso8601(event.fetch("date")),
          type: event.fetch("type"),
          label: event.fetch("label"),
          note: event["note"].to_s
        }.freeze
      end
    end

    def config_data
      @config_data ||= YAML.safe_load(
        File.read(Rails.root.join("config/bvg_strike_days.yml")),
        permitted_classes: [],
        aliases: false
      )
    end
  end
end
