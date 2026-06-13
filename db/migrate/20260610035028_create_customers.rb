class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :external_id, null: false
      t.string :name
      t.string :email

      t.timestamps
    end
    add_index :customers, :external_id, unique: true
  end
end
