class CreateBikeCounts < ActiveRecord::Migration[8.1]
  def change
    create_table :bike_counts do |t|
      t.references :counting_station, null: false, foreign_key: true
      t.datetime :counted_at, null: false
      t.integer :count, null: false

      t.timestamps
    end

    add_index :bike_counts, [ :counting_station_id, :counted_at ], unique: true
  end
end
