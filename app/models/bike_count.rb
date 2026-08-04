class BikeCount < ApplicationRecord
  belongs_to :counting_station

  validates :counted_at, presence: true
  validates :count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :counted_at, uniqueness: { scope: :counting_station_id }
end
