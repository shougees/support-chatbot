class CreateSupportActions < ActiveRecord::Migration[8.1]
  def change
    create_table :support_actions do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :message, null: true, foreign_key: true
      t.references :human_review, null: true, foreign_key: true
      t.string :action_type, null: false
      t.string :status, null: false, default: "proposed"
      t.text :policy_reference_ids
      t.text :eligibility_reason
      t.text :metadata

      t.timestamps
    end

    add_index :support_actions, :action_type
    add_index :support_actions, :status
  end
end
