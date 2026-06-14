class CreateKnowledgeDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_documents do |t|
      t.string :title, null: false
      t.string :source_type, null: false, default: "manual"
      t.string :source_identifier
      t.string :category
      t.text :body
      t.text :extracted_text
      t.string :status, null: false, default: "draft"
      t.text :metadata

      t.timestamps
    end

    add_index :knowledge_documents, :status
    add_index :knowledge_documents, :source_type
  end
end
