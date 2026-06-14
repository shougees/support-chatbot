class CreateHumanReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :human_reviews do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :message, null: true, foreign_key: true
      t.references :operator_user, null: true, foreign_key: true
      t.string :status, null: false, default: "open"
      t.text :reason
      t.text :summary
      t.decimal :confidence, precision: 5, scale: 2
      t.string :key_decision
      t.text :decision_payload
      t.text :agent_response

      t.timestamps
    end

    add_index :human_reviews, :status
    add_index :human_reviews, :key_decision
  end
end
