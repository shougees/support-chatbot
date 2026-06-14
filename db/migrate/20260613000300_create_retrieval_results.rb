class CreateRetrievalResults < ActiveRecord::Migration[8.1]
  def change
    create_table :retrieval_results do |t|
      t.references :message, null: false, foreign_key: true
      t.references :knowledge_document, null: false, foreign_key: true
      t.decimal :score, precision: 10, scale: 4, null: false, default: 0
      t.integer :rank, null: false
      t.text :metadata

      t.timestamps
    end

    add_index :retrieval_results, [ :message_id, :rank ], unique: true
    add_index :retrieval_results, [ :message_id, :knowledge_document_id ], unique: true
  end
end
