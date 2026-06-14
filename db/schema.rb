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

ActiveRecord::Schema[8.1].define(version: 2026_06_13_000800) do
  create_table "bot_agents", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "llm_model", default: "gpt-4o", null: false
    t.string "name", null: false
    t.string "provider", default: "openai", null: false
    t.text "system_prompt"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_bot_agents_on_active"
  end

  create_table "conversations", force: :cascade do |t|
    t.string "public_id", null: false
    t.string "status", default: "open", null: false
    t.string "category"
    t.datetime "operator_review_requested_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "customer_id"
    t.index ["customer_id"], name: "index_conversations_on_customer_id"
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

  create_table "feedbacks", force: :cascade do |t|
    t.integer "message_id", null: false
    t.string "rating", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "rating"], name: "index_feedbacks_on_message_id_and_rating"
    t.index ["message_id"], name: "index_feedbacks_on_message_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.string "public_role", null: false
    t.text "body", null: false
    t.text "metadata", default: "{}"
    t.string "author_type"
    t.integer "author_id"
    t.string "published_by_type"
    t.integer "published_by_id"
    t.integer "response_draft_id"
    t.integer "position", null: false
    t.string "origin", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_messages_on_author"
    t.index ["conversation_id", "position"], name: "index_messages_on_conversation_id_and_position", unique: true
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["origin"], name: "index_messages_on_origin"
    t.index ["public_role"], name: "index_messages_on_public_role"
    t.index ["published_by_type", "published_by_id"], name: "index_messages_on_published_by"
    t.index ["response_draft_id"], name: "index_messages_on_response_draft_id"
  end

  create_table "knowledge_documents", force: :cascade do |t|
    t.string "title", null: false
    t.string "source_type", default: "manual", null: false
    t.string "source_identifier"
    t.string "category"
    t.text "body"
    t.text "extracted_text"
    t.string "status", default: "draft", null: false
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_type"], name: "index_knowledge_documents_on_source_type"
    t.index ["status"], name: "index_knowledge_documents_on_status"
  end

  create_table "operator_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_operator_users_on_email", unique: true
  end

  create_table "response_drafts", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.integer "bot_agent_id"
    t.text "body", null: false
    t.string "status", default: "draft", null: false
    t.decimal "confidence", precision: 5, scale: 2, null: false
    t.string "category"
    t.string "proposed_action_type"
    t.text "proposed_action_payload"
    t.text "review_reason"
    t.boolean "upload_requested", default: false, null: false
    t.string "upload_type"
    t.text "raw_provider_response"
    t.text "metadata", default: "{}"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_agent_id"], name: "index_response_drafts_on_bot_agent_id"
    t.index ["confidence"], name: "index_response_drafts_on_confidence"
    t.index ["conversation_id"], name: "index_response_drafts_on_conversation_id"
    t.index ["status"], name: "index_response_drafts_on_status"
  end

  create_table "response_reviews", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.integer "message_id"
    t.integer "response_draft_id", null: false
    t.integer "operator_user_id"
    t.string "status", default: "pending", null: false
    t.text "reason"
    t.text "summary"
    t.string "key_decision"
    t.text "decision_payload"
    t.text "edited_body"
    t.text "agent_response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_response_reviews_on_conversation_id"
    t.index ["key_decision"], name: "index_response_reviews_on_key_decision"
    t.index ["message_id"], name: "index_response_reviews_on_message_id"
    t.index ["operator_user_id"], name: "index_response_reviews_on_operator_user_id"
    t.index ["response_draft_id"], name: "index_response_reviews_on_response_draft_id"
    t.index ["status"], name: "index_response_reviews_on_status"
  end

  create_table "retrieval_results", force: :cascade do |t|
    t.integer "message_id", null: false
    t.integer "knowledge_document_id", null: false
    t.decimal "score", precision: 10, scale: 4, default: "0.0", null: false
    t.integer "rank", null: false
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["knowledge_document_id"], name: "index_retrieval_results_on_knowledge_document_id"
    t.index ["message_id", "knowledge_document_id"], name: "idx_on_message_id_knowledge_document_id_cadddc831f", unique: true
    t.index ["message_id", "rank"], name: "index_retrieval_results_on_message_id_and_rank", unique: true
    t.index ["message_id"], name: "index_retrieval_results_on_message_id"
  end

  create_table "support_actions", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.integer "message_id"
    t.integer "response_review_id"
    t.string "action_type", null: false
    t.string "status", default: "proposed", null: false
    t.text "policy_reference_ids"
    t.text "eligibility_reason"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_support_actions_on_action_type"
    t.index ["conversation_id"], name: "index_support_actions_on_conversation_id"
    t.index ["response_review_id"], name: "index_support_actions_on_response_review_id"
    t.index ["message_id"], name: "index_support_actions_on_message_id"
    t.index ["status"], name: "index_support_actions_on_status"
  end

  create_table "uploads", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.integer "message_id"
    t.string "file_type", null: false
    t.string "processing_status", default: "pending", null: false
    t.text "extracted_text"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_uploads_on_conversation_id"
    t.index ["message_id"], name: "index_uploads_on_message_id"
    t.index ["processing_status"], name: "index_uploads_on_processing_status"
  end

  add_foreign_key "conversations", "customers"
  add_foreign_key "feedbacks", "messages"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "response_drafts"
  add_foreign_key "response_drafts", "bot_agents"
  add_foreign_key "response_drafts", "conversations"
  add_foreign_key "response_reviews", "conversations"
  add_foreign_key "response_reviews", "messages"
  add_foreign_key "response_reviews", "operator_users"
  add_foreign_key "response_reviews", "response_drafts"
  add_foreign_key "retrieval_results", "knowledge_documents"
  add_foreign_key "retrieval_results", "messages"
  add_foreign_key "support_actions", "conversations"
  add_foreign_key "support_actions", "messages"
  add_foreign_key "support_actions", "response_reviews"
  add_foreign_key "uploads", "conversations"
  add_foreign_key "uploads", "messages"
end
