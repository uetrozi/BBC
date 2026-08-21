class BikeCountsController < ApplicationController
  RESULTS_PER_PAGE = 100
  PRIMARY_WEATHER_STATION_EXTERNAL_ID = "00433"
  CHART_COLORS = [
    { border: "#005f73", background: "rgba(0, 95, 115, 0.16)" },
    { border: "#0a9396", background: "rgba(10, 147, 150, 0.16)" },
    { border: "#ee9b00", background: "rgba(238, 155, 0, 0.16)" },
    { border: "#ca6702", background: "rgba(202, 103, 2, 0.16)" },
    { border: "#9b2226", background: "rgba(155, 34, 38, 0.16)" }
  ].freeze

  def index
    @stations = CountingStation
      .joins(:bike_counts)
      .where("counting_stations.external_id NOT LIKE ?", "DEMO-%")
      .distinct
      .order(:external_id)
    @filter_values = filter_values
    base_scope = BikeCount
      .includes(:counting_station)
      .select(:id, :counted_at, :count, :counting_station_id)
      .order(counted_at: :desc)

    query_result = BikeCounts::FilterQuery.new(
      scope: base_scope,
      params: @filter_values
    ).call

    @filter_errors = query_result.errors
    @field_errors = query_result.field_errors
    @selected_station_ids = query_result.selected_station_ids.map(&:to_s)
    @station_options = station_options(query_result.unknown_station_ids)
    @current_page = parsed_page

    filtered_scope = query_result.scope
    @statistics = BikeCounts::Statistics.new(scope: filtered_scope).call
    @chart_labels = @statistics.daily_series.map { |daily_total| daily_total[:date] }
    @chart_strike_events = @statistics.daily_series.map do |daily_total|
      {
        bvg_strike: daily_total[:bvg_strike],
        label: daily_total[:bvg_strike_label],
        note: daily_total[:bvg_strike_note]
      }
    end
    @chart_datasets = build_chart_datasets(filtered_scope, query_result.selected_station_ids, @chart_strike_events)
    @comparison_mode = query_result.selected_station_ids.size > 1
    @weather_station = selected_weather_station
    @weather_correlation = build_weather_correlation(filtered_scope)

    @total_matching = filtered_scope.except(:select).count
    @total_pages = [ (@total_matching.to_f / RESULTS_PER_PAGE).ceil, 1 ].max
    @current_page = @total_pages if @current_page > @total_pages

    @bike_counts = filtered_scope.limit(RESULTS_PER_PAGE).offset((@current_page - 1) * RESULTS_PER_PAGE)
    @pagination_params = @filter_values.compact_blank
    @has_filters = @filter_values.values.any?(&:present?)
    @selected_station_label = selected_station_label
  end

  private

  def filter_values
    {
      station_ids: parsed_station_ids,
      from: params[:from].to_s,
      to: params[:to].to_s
    }
  end

  def parsed_page
    page = Integer(params[:page] || 1)
    page.positive? ? page : 1
  rescue ArgumentError, TypeError
    1
  end

  def station_options(unknown_station_ids)
    options = @stations.map { |station| [ station.name, station.id ] }
    return options if unknown_station_ids.blank?

    unknown_station_ids.each do |unknown_station_id|
      options << [ "Unknown station (ID #{unknown_station_id})", unknown_station_id ]
    end
    options
  end

  def selected_station_label
    return "Alle Zählstellen" if @selected_station_ids.blank?

    labels = @selected_station_ids.filter_map do |station_id|
      @station_options.find { |label, value| value.to_s == station_id }&.first
    end

    labels.presence&.join(", ") || "Unbekannte Zählstelle"
  end

  def parsed_station_ids
    station_ids = Array(params[:station_ids]).map(&:to_s).reject(&:blank?)
    if station_ids.empty? && params[:station_id].present?
      station_ids = [ params[:station_id].to_s ]
    end

    station_ids.uniq
  end

  def build_chart_datasets(filtered_scope, selected_station_ids, strike_events)
    if selected_station_ids.size > 1
      build_comparison_chart_datasets(filtered_scope, selected_station_ids, strike_events)
    else
      [
        chart_dataset(
          label: "Gesamt (alle gewählten Zählstellen)",
          values: @statistics.daily_series.map { |daily_total| daily_total[:count] },
          color_index: 0,
          fill: true,
          strike_events: strike_events
        )
      ]
    end
  end

  def build_comparison_chart_datasets(filtered_scope, selected_station_ids, strike_events)
    grouped_counts = filtered_scope
      .except(:includes, :preload, :eager_load, :order, :limit, :offset, :select)
      .group(:counting_station_id, "DATE(bike_counts.counted_at)")
      .sum(:count)

    counts_by_station_and_day = Hash.new { |hash, key| hash[key] = {} }
    grouped_counts.each do |(station_id, counted_on), count|
      date = counted_on.is_a?(Date) ? counted_on.iso8601 : Date.iso8601(counted_on.to_s).iso8601
      counts_by_station_and_day[station_id][date] = count.to_i
    end

    selected_station_ids.each_with_index.map do |station_id, index|
      label = @station_options.find { |_label, value| value.to_s == station_id.to_s }&.first || "Station #{station_id}"
      values = @chart_labels.map { |date| counts_by_station_and_day[station_id][date] }

      chart_dataset(
        label: label,
        values: values,
        color_index: index,
        fill: false,
        strike_events: strike_events
      )
    end
  end

  def chart_dataset(label:, values:, color_index:, fill:, strike_events:)
    colors = CHART_COLORS[color_index % CHART_COLORS.size]
    {
      label: label,
      data: values,
      borderColor: colors[:border],
      backgroundColor: colors[:background],
      borderWidth: 2,
      fill: fill,
      tension: 0.2,
      pointRadius: values.each_with_index.map { |value, index| strike_point_radius(value, strike_events[index]) },
      pointStyle: values.each_with_index.map { |value, index| strike_point_style(value, strike_events[index]) },
      pointBackgroundColor: values.each_with_index.map { |_value, index| strike_point_color(colors[:border], strike_events[index]) },
      pointBorderColor: values.each_with_index.map { |_value, index| strike_point_color(colors[:border], strike_events[index]) },
      pointBorderWidth: values.each_with_index.map { |value, index| strike_point_border_width(value, strike_events[index]) },
      strikeEvents: strike_events,
      spanGaps: true
    }
  end

  def strike_point_style(value, strike_event)
    return "circle" if value.nil?

    strike_event&.dig(:bvg_strike) ? "triangle" : "circle"
  end

  def strike_point_radius(value, strike_event)
    return 0 if value.nil?

    strike_event&.dig(:bvg_strike) ? 5 : 2
  end

  def strike_point_border_width(value, strike_event)
    return 0 if value.nil?

    strike_event&.dig(:bvg_strike) ? 2 : 1
  end

  def strike_point_color(default_color, strike_event)
    strike_event&.dig(:bvg_strike) ? "#9b2226" : default_color
  end

  def selected_weather_station
    WeatherStation.find_by(external_id: PRIMARY_WEATHER_STATION_EXTERNAL_ID) || WeatherStation.order(:external_id).first
  end

  def build_weather_correlation(filtered_scope)
    return BikeCounts::WeatherCorrelationAnalysis.empty_result if @weather_station.nil?

    BikeCounts::WeatherCorrelationAnalysis.new(
      scope: filtered_scope,
      weather_station: @weather_station
    ).call
  end
end
