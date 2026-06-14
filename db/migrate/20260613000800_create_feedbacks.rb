class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      t.references :message, null: false, foreign_key: true
      t.string :rating, null: false
      t.text :note

      t.timestamps
    end

    add_index :feedbacks, [ :message_id, :rating ]
  end
end
