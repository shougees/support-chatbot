class CreateBots < ActiveRecord::Migration[8.1]
  def change
    create_table :bots do |t|
      t.string :name, null: false
      t.string :provider, null: false, default: "openai"
      t.string :llm_model, null: false, default: "gpt-4o"
      t.text :system_prompt
      t.boolean :active, null: false, default: false

      t.timestamps
    end

    add_index :bots, :active
  end
end
