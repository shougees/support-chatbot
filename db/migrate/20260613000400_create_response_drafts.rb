class CreateResponseDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :response_drafts do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :bot_agent, null: true, foreign_key: true
      t.text :body, null: false
      t.string :status, null: false, default: "draft"
      t.decimal :confidence, precision: 5, scale: 2, null: false
      t.string :category
      t.string :proposed_action_type
      t.text :proposed_action_payload
      t.text :review_reason
      t.boolean :upload_requested, null: false, default: false
      t.string :upload_type
      t.text :raw_provider_response
      t.text :metadata, default: "{}"

      t.timestamps
    end

    add_index :response_drafts, :confidence
    add_index :response_drafts, :status
    add_foreign_key :messages, :response_drafts
  end
end
