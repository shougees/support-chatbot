class BotResponseJob < ApplicationJob
  queue_as :default

  FALLBACK_BODY = "We are checking this and will reply here.".freeze
  FALLBACK_REVIEW_REASON = "Bot response job failed.".freeze

  def perform(conversation, message)
    BotOrchestrator.call(conversation: conversation, message: message)
  rescue StandardError => error
    Rails.logger.error(
      "[BotResponseJob] Failed for conversation_id=#{conversation.id} message_id=#{message.id}: #{error.class}: #{error.message}"
    )
    Rails.logger.debug(error.backtrace.first(5).join("\n")) if error.backtrace.present?

    create_fallback_review!(conversation, message, error)
  end

  private

  def create_fallback_review!(conversation, message, error)
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
        raw_provider_response: "#{error.class}: #{error.message}",
        metadata: {
          failure_reason: FALLBACK_REVIEW_REASON,
          job_error: {
            class: error.class.name,
            message: error.message,
            retryable: true,
            failed_at: Time.current.iso8601,
            failed_message_id: message.id
          }
        }.to_json
      )

      response_draft.response_reviews.create!(
        conversation: conversation,
        status: "pending",
        key_decision: "response_publication",
        reason: FALLBACK_REVIEW_REASON,
        summary: "Automatic response generation failed; review the fallback before replying."
      )
    end
  end
end
