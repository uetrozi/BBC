class BikeCountsController < ApplicationController
  RESULTS_PER_PAGE = 100

  def index
    @stations = CountingStation.order(:external_id)
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
    @station_options = station_options(query_result.unknown_station_id)
    @current_page = parsed_page

    filtered_scope = query_result.scope
    @statistics = BikeCounts::Statistics.new(scope: filtered_scope).call
    @chart_labels = @statistics.daily_series.map { |daily_total| daily_total[:date] }
    @chart_values = @statistics.daily_series.map { |daily_total| daily_total[:count] }

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
      station_id: params[:station_id].to_s,
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

  def station_options(unknown_station_id)
    options = @stations.map { |station| [ "#{station.external_id} - #{station.name}", station.id ] }
    return options unless unknown_station_id

    options << [ "Unknown station (ID #{@filter_values[:station_id]})", @filter_values[:station_id] ]
  end

  def selected_station_label
    selected_id = @filter_values[:station_id]
    return "All stations" if selected_id.blank?

    @station_options.find { |label, value| value.to_s == selected_id }&.first || "Unknown station"
  end
end
