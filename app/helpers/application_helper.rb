module ApplicationHelper
  def format_counted_at(value)
    value.in_time_zone.strftime("%Y-%m-%d %H:%M")
  end

  def format_date(value)
    value.strftime("%Y-%m-%d")
  end
end
