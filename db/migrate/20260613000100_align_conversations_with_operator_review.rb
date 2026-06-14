class AlignConversationsWithOperatorReview < ActiveRecord::Migration[8.1]
  def change
    rename_column :conversations, :escalated_at, :operator_review_requested_at
    add_reference :conversations, :customer, null: true, foreign_key: true
  end
end
