class WeatherObservation < ApplicationRecord
  belongs_to :weather_station

  validates :observed_on, presence: true, uniqueness: { scope: :weather_station_id }
  validates :mean_temperature, numericality: true, allow_nil: true
  validates :precipitation, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :at_least_one_measurement

  private

  def at_least_one_measurement
    return if mean_temperature.present? || precipitation.present?

    errors.add(:base, "At least one weather measurement must be present.")
  end
end
