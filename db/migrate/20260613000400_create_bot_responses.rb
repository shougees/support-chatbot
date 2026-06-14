class CreateBotResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :bot_responses do |t|
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      t.decimal :confidence, precision: 5, scale: 2, null: false
      t.string :category
      t.string :proposed_action_type
      t.text :proposed_action_payload
      t.boolean :human_review_recommended, null: false, default: false
      t.text :human_review_reason
      t.boolean :upload_requested, null: false, default: false
      t.string :upload_type
      t.text :raw_provider_response

      t.timestamps
    end

    add_index :bot_responses, :confidence
    add_index :bot_responses, :human_review_recommended
  end
end
