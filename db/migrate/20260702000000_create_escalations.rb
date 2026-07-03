class CreateEscalations < ActiveRecord::Migration[8.1]
  def change
    create_table :escalations do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :message, foreign_key: true
      t.references :response_review, foreign_key: true
      t.references :operator_user, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :reason, null: false
      t.text :summary, null: false
      t.text :metadata, default: "{}"
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :escalations, :status
    add_index :escalations, :reason
  end
end
