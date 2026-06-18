class BotResponseJob < ApplicationJob
  queue_as :default

  FALLBACK_BODY = "We are having trouble checking this automatically. A support operator can review the conversation before we reply.".freeze
  FALLBACK_REVIEW_REASON = "Bot response job failed.".freeze

  def perform(conversation, message)
    BotOrchestrator.call(conversation: conversation, message: message)
  rescue StandardError => error
    Rails.logger.error(
      "[BotResponseJob] Failed for conversation_id=#{conversation.id} message_id=#{message.id}: #{error.class}: #{error.message}"
    )

    create_fallback_review!(conversation, error)
  end

  private

  def create_fallback_review!(conversation, error)
    ResponseDraft.transaction do
      conversation.update!(
        status: "pending_operator_review",
        operator_review_requested_at: Time.current
      )

      response_draft = conversation.response_drafts.create!(
        bot_agent: BotAgent.current,
        body: FALLBACK_BODY,
        status: "pending_review",
        confidence: 0,
        category: "fallback",
        review_reason: FALLBACK_REVIEW_REASON,
        raw_provider_response: "#{error.class}: #{error.message}"
      )

      response_draft.response_reviews.create!(
        conversation: conversation,
        status: "pending",
        key_decision: "response_publication",
        reason: FALLBACK_REVIEW_REASON,
        summary: "Review the conversation because automatic bot response generation failed."
      )
    end
  end
end
