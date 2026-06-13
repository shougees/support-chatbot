class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :public_id, null: false
      t.string :status, null: false, default: "open"
      t.string :category
      t.datetime :escalated_at
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :conversations, :public_id, unique: true
    add_index :conversations, :status
  end
end
