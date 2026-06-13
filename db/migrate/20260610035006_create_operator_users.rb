class CreateOperatorUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :operator_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :operator_users, :email, unique: true
  end
end
