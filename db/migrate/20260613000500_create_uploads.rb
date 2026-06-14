class CreateUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :uploads do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :message, null: true, foreign_key: true
      t.string :file_type, null: false
      t.string :processing_status, null: false, default: "pending"
      t.text :extracted_text
      t.text :metadata

      t.timestamps
    end

    add_index :uploads, :processing_status
  end
end
