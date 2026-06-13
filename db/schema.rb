# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_10_035215) do
  create_table "bots", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "llm_model", default: "gpt-4o", null: false
    t.string "name", null: false
    t.string "provider", default: "openai", null: false
    t.text "system_prompt"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_bots_on_active"
  end

  create_table "conversations", force: :cascade do |t|
    t.string "public_id", null: false
    t.string "status", default: "open", null: false
    t.string "category"
    t.datetime "escalated_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_conversations_on_public_id", unique: true
    t.index ["status"], name: "index_conversations_on_status"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "external_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_customers_on_external_id", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.string "role", null: false
    t.text "body", null: false
    t.text "metadata"
    t.string "author_type"
    t.integer "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_messages_on_author"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["role"], name: "index_messages_on_role"
  end

  create_table "operator_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_operator_users_on_email", unique: true
  end

  add_foreign_key "messages", "conversations"
end
