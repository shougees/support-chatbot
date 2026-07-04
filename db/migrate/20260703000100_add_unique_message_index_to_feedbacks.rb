class AddUniqueMessageIndexToFeedbacks < ActiveRecord::Migration[8.1]
  def change
    add_index :feedbacks, :message_id, unique: true, name: "index_feedbacks_on_message_id_unique"
  end
end
