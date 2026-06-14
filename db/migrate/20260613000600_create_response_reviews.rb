class CreateResponseReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :response_reviews do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :message, null: true, foreign_key: true
      t.references :response_draft, null: false, foreign_key: true
      t.references :operator_user, null: true, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.text :reason
      t.text :summary
      t.string :key_decision
      t.text :decision_payload
      t.text :edited_body
      t.text :agent_response

      t.timestamps
    end

    add_index :response_reviews, :status
    add_index :response_reviews, :key_decision
  end
end
