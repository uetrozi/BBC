class CreateCountingStations < ActiveRecord::Migration[8.1]
  def change
    create_table :counting_stations do |t|
      t.string :external_id, null: false
      t.string :name, null: false
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.date :installed_at

      t.timestamps
    end

    add_index :counting_stations, :external_id, unique: true
  end
end
