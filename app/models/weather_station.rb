class WeatherStation < ApplicationRecord
  has_many :weather_observations, dependent: :destroy

  validates :external_id, presence: true, uniqueness: true
  validates :name, presence: true
end
