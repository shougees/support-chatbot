class CreateAgentDecisionTraces < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_decision_traces do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      t.references :bot_agent, foreign_key: true
      t.references :response_draft, foreign_key: true
      t.references :response_review, foreign_key: true
      t.references :published_message, foreign_key: { to_table: :messages }
      t.string :outcome, null: false
      t.string :provider_name
      t.string :provider_model
      t.string :response_category
      t.decimal :confidence, precision: 5, scale: 2
      t.string :review_status
      t.boolean :review_required, default: false, null: false
      t.text :retrieved_knowledge_document_ids, default: "[]"
      t.text :proposed_tool_names, default: "[]"
      t.text :proposed_action_types, default: "[]"
      t.text :metadata, default: "{}"
      t.timestamps
    end

    add_index :agent_decision_traces, :outcome
  end
end
