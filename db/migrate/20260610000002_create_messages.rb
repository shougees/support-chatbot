class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :public_role, null: false
      t.text :body, null: false
      t.integer :position, null: false
      t.string :origin, null: false
      t.text :metadata, default: "{}"
      t.references :author, polymorphic: true, null: true
      t.references :published_by, polymorphic: true, null: true
      t.references :response_draft, null: true

      t.timestamps
    end

    add_index :messages, :public_role
    add_index :messages, [ :conversation_id, :position ], unique: true
    add_index :messages, :origin
  end
end
