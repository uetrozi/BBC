module ApplicationHelper
  GERMAN_MONTH_NAMES = [
    nil, "Januar", "Februar", "März", "April", "Mai", "Juni",
    "Juli", "August", "September", "Oktober", "November", "Dezember"
  ].freeze
  GERMAN_WEEKDAY_NAMES = [
    "Sonntag", "Montag", "Dienstag", "Mittwoch",
    "Donnerstag", "Freitag", "Samstag"
  ].freeze

  def format_counted_at(value)
    timestamp = value.in_time_zone
    "#{format_date(timestamp.to_date)}, #{timestamp.strftime('%H:%M')}"
  end

  def format_date(value)
    date = value.to_date
    "#{date.day}. #{GERMAN_MONTH_NAMES[date.month]} #{date.year}"
  end

  def format_date_with_weekday(value)
    date = value.to_date
    "#{GERMAN_WEEKDAY_NAMES[date.wday]}, #{format_date(date)}"
  end

  def format_optional_filter_date(value)
    return nil if value.blank?

    format_date(Date.iso8601(value))
  rescue ArgumentError
    value
  end

  def format_optional_filter_date_with_weekday(value)
    return nil if value.blank?

    format_date_with_weekday(Date.iso8601(value))
  rescue ArgumentError
    value
  end

  def format_integer(value)
    number_with_delimiter(value, delimiter: ".")
  end

  def format_decimal(value, precision: 2)
    number_with_precision(value, precision: precision, delimiter: ".", separator: ",")
  end

  def format_correlation(value)
    return "Nicht ausreichend Daten" if value.nil?

    formatted = format_decimal(value, precision: 2)
    value.positive? ? "+#{formatted}" : formatted
  end
end
