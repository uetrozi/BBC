class ImportBatch < ApplicationRecord
  STATUSES = %w[running completed completed_with_errors failed].freeze

  validates :filename, presence: true
  validates :imported_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
