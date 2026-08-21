class CreateWeatherStationsAndObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :weather_stations do |t|
      t.string :external_id, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :weather_stations, :external_id, unique: true

    create_table :weather_observations do |t|
      t.references :weather_station, null: false, foreign_key: true
      t.date :observed_on, null: false
      t.decimal :mean_temperature, precision: 5, scale: 2
      t.decimal :precipitation, precision: 6, scale: 2

      t.timestamps
    end

    add_index :weather_observations, [ :weather_station_id, :observed_on ], unique: true
    add_index :weather_observations, :observed_on
  end
end
