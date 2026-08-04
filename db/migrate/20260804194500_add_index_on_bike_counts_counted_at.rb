class AddIndexOnBikeCountsCountedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :bike_counts, :counted_at
  end
end
