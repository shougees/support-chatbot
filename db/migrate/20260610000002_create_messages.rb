class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :body, null: false
      t.text :metadata
      t.references :author, polymorphic: true, null: true

      t.timestamps
    end

    add_index :messages, :role
  end
end
