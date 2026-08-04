class CreateImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :import_batches do |t|
      t.string :filename, null: false
      t.datetime :imported_at, null: false
      t.integer :rows_read, null: false, default: 0
      t.integer :imported_rows, null: false, default: 0
      t.integer :skipped_duplicates, null: false, default: 0
      t.integer :invalid_rows, null: false, default: 0
      t.string :status, null: false

      t.timestamps
    end

    add_index :import_batches, :imported_at
    add_index :import_batches, :status
  end
end
