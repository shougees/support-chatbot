class SupportAnalyticsSnapshot
  DEFAULT_ATTENTION_LIMIT = 10

  Result = Struct.new(
    :total_conversations,
    :escalated_conversations,
    :escalation_rate,
    :feedback_responses,
    :helpfulness_rate,
    :top_categories,
    :attention_conversations,
    :confidence_threshold,
    keyword_init: true
  )

  def self.call(...)
    new(...).call
  end

  def initialize(
    confidence_threshold: ENV.fetch("BOT_CONFIDENCE_THRESHOLD", BotOrchestrator::DEFAULT_CONFIDENCE_THRESHOLD).to_f,
    attention_limit: DEFAULT_ATTENTION_LIMIT
  )
    @confidence_threshold = confidence_threshold.to_f
    @attention_limit = attention_limit.to_i
  end

  def call
    total_conversations = Conversation.count
    escalated_conversations = Escalation.distinct.count(:conversation_id)
    feedback_responses = Feedback.count

    Result.new(
      total_conversations: total_conversations,
      escalated_conversations: escalated_conversations,
      escalation_rate: percentage(escalated_conversations, total_conversations),
      feedback_responses: feedback_responses,
      helpfulness_rate: percentage(Feedback.where(rating: "helpful").count, feedback_responses),
      top_categories: top_categories,
      attention_conversations: attention_conversations,
      confidence_threshold: confidence_threshold
    )
  end

  private

  attr_reader :confidence_threshold, :attention_limit

  def percentage(numerator, denominator)
    return if denominator.zero?

    (numerator.fdiv(denominator) * 100).round(1)
  end

  def top_categories
    ResponseDraft
      .where.not(category: [ nil, "" ])
      .group(:category)
      .count
      .sort_by { |category, count| [ -count, category ] }
      .first(5)
  end

  def attention_conversations
    low_confidence_conversation_ids = ResponseDraft
      .low_confidence(confidence_threshold)
      .select(:conversation_id)

    Conversation
      .where.not(status: "closed")
      .or(Conversation.where(id: low_confidence_conversation_ids))
      .includes(:escalations, :response_drafts)
      .order(updated_at: :desc, created_at: :desc)
      .limit(attention_limit)
  end
end
