# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

OperatorUser.find_or_create_by!(email: "operator@example.test") do |operator|
  operator.password = "password"
end

BotAgent.find_or_create_by!(name: "Support Bot") do |bot|
  bot.provider = "openai"
  bot.llm_model = "gpt-4o"
  bot.active = true
  bot.system_prompt = "Use concise, policy-grounded support language. Use we instead of first-person singular phrasing."
end


unless Rails.env.production?
  customer = Customer.find_or_create_by!(external_id: "demo-customer-001") do |record|
    record.email = "customer@example.test"
    record.name = "Demo Customer"
  end

  conversation = Conversation.find_or_create_by!(public_id: "demo-review-conversation") do |record|
    record.customer = customer
    record.status = "pending_operator_review"
    record.category = "damaged_item"
    record.operator_review_requested_at = Time.current
  end

  conversation.messages.find_or_create_by!(position: 1) do |message|
    message.public_role = "customer"
    message.origin = "customer_submitted"
    message.author = customer
    message.published_by = customer
    message.body = "My order arrived with a damaged item. Can we get help?"
  end

  draft = conversation.response_drafts.find_or_create_by!(category: "damaged_item") do |response_draft|
    response_draft.bot_agent = BotAgent.find_by!(name: "Support Bot")
    response_draft.body = "We can help with the damaged item. Please confirm whether the shipping box was also damaged."
    response_draft.status = "pending_review"
    response_draft.confidence = 64.0
    response_draft.review_reason = "Confidence is below the configured threshold for replacement eligibility."
    response_draft.upload_requested = true
    response_draft.upload_type = "image"
  end

  draft.response_reviews.find_or_create_by!(key_decision: "response_publication") do |review|
    review.conversation = conversation
    review.status = "pending"
    review.reason = draft.review_reason
    review.summary = "Customer reports a damaged item and may need replacement review."
  end
end
