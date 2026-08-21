# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_19_175500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bike_counts", force: :cascade do |t|
    t.integer "count", null: false
    t.datetime "counted_at", null: false
    t.bigint "counting_station_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["counted_at"], name: "index_bike_counts_on_counted_at"
    t.index ["counting_station_id", "counted_at"], name: "index_bike_counts_on_counting_station_id_and_counted_at", unique: true
    t.index ["counting_station_id"], name: "index_bike_counts_on_counting_station_id"
  end

  create_table "counting_stations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.date "installed_at"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_counting_stations_on_external_id", unique: true
  end

  create_table "import_batches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.datetime "imported_at", null: false
    t.integer "imported_rows", default: 0, null: false
    t.integer "invalid_rows", default: 0, null: false
    t.integer "rows_read", default: 0, null: false
    t.integer "skipped_duplicates", default: 0, null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["imported_at"], name: "index_import_batches_on_imported_at"
    t.index ["status"], name: "index_import_batches_on_status"
  end

  create_table "weather_observations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "mean_temperature", precision: 5, scale: 2
    t.date "observed_on", null: false
    t.decimal "precipitation", precision: 6, scale: 2
    t.datetime "updated_at", null: false
    t.bigint "weather_station_id", null: false
    t.index ["observed_on"], name: "index_weather_observations_on_observed_on"
    t.index ["weather_station_id", "observed_on"], name: "idx_on_weather_station_id_observed_on_5b8fdff0d7", unique: true
    t.index ["weather_station_id"], name: "index_weather_observations_on_weather_station_id"
  end

  create_table "weather_stations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_weather_stations_on_external_id", unique: true
  end

  add_foreign_key "bike_counts", "counting_stations"
  add_foreign_key "weather_observations", "weather_stations"
end
