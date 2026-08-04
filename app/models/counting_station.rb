class CountingStation < ApplicationRecord
  has_many :bike_counts, dependent: :destroy

  validates :external_id, presence: true, uniqueness: true
  validates :name, presence: true
end
