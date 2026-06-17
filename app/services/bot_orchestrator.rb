class BotOrchestrator
  DEFAULT_CONFIDENCE_THRESHOLD = 70
  MAX_RETRIEVAL_RESULTS = 3

  Result = Struct.new(:response_draft, :message, :response_review, :retrieval_results, keyword_init: true) do
    def published?
      message.present?
    end

    def pending_review?
      response_review.present?
    end
  end

  class StubProvider
    def call(conversation:, message:, bot_agent:, retrieved_documents:)
      return fallback_output("No active bot agent is configured.") if bot_agent.blank?

      body = message.body.downcase

      if body.match?(/agent|human|representative|lawyer|legal|fraud|chargeback|identity|emergency/)
        review_output("This request needs operator review before support replies.", "High-risk or operator-request context detected.")
      elsif body.match?(/refund|return|replace|replacement|damaged|broken|missing/)
        if body.match?(/photo|image|picture|damaged|broken/)
          upload_output(retrieved_documents)
        else
          review_output("We can help review the order and determine the next best step.", "Action eligibility requires operator review.")
        end
      else
        success_output(retrieved_documents)
      end
    end

    private

    def success_output(retrieved_documents)
      source_text = retrieved_documents.any? ? " We found relevant support guidance to help with this." : ""

      {
        body: "We can help with that.#{source_text}",
        confidence: 82,
        category: "general_support",
        status: "draft",
        raw_provider_response: "stubbed_success"
      }
    end

    def upload_output(retrieved_documents)
      source_text = retrieved_documents.any? ? " Based on the relevant policy context," : ""

      {
        body: "#{source_text} please upload a clear image so we can review the item condition.",
        confidence: 76,
        category: "damaged_item",
        status: "draft",
        upload_requested: true,
        upload_type: "image",
        raw_provider_response: "stubbed_upload_request"
      }
    end

    def review_output(body, reason)
      {
        body: body,
        confidence: 62,
        category: "operator_review",
        status: "pending_review",
        review_reason: reason,
        raw_provider_response: "stubbed_operator_review"
      }
    end

    def fallback_output(reason)
      {
        body: "We need a support operator to review this before replying.",
        confidence: 0,
        category: "fallback",
        status: "pending_review",
        review_reason: reason,
        raw_provider_response: "stubbed_fallback"
      }
    end
  end

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(conversation:, message:, bot_agent: BotAgent.current, confidence_threshold: default_confidence_threshold, provider: StubProvider.new)
    @conversation = conversation
    @message = message
    @bot_agent = bot_agent
    @confidence_threshold = confidence_threshold.to_f
    @provider = provider
  end

  def call
    validate_message!

    retrieved_documents = retrieve_documents
    retrieval_results = record_retrieval_results(retrieved_documents)
    bot_output = provider.call(
      conversation: conversation,
      message: message,
      bot_agent: bot_agent,
      retrieved_documents: retrieved_documents
    )

    ResponseDraft.transaction do
      response_draft = create_response_draft!(bot_output)

      if review_required?(response_draft)
        response_review = request_operator_review!(response_draft)

        Result.new(
          response_draft: response_draft,
          response_review: response_review,
          retrieval_results: retrieval_results
        )
      else
        published_message = publish_bot_message!(response_draft)

        Result.new(
          response_draft: response_draft,
          message: published_message,
          retrieval_results: retrieval_results
        )
      end
    end
  end

  private

  attr_reader :conversation, :message, :bot_agent, :confidence_threshold, :provider

  def default_confidence_threshold
    ENV.fetch("BOT_CONFIDENCE_THRESHOLD", DEFAULT_CONFIDENCE_THRESHOLD).to_f
  end

  def validate_message!
    unless message.conversation == conversation
      raise ArgumentError, "message must belong to conversation"
    end

    return if message.customer?

    raise ArgumentError, "message must be a customer message"
  end

  def retrieve_documents
    scored_documents = KnowledgeDocument.retrievable.filter_map do |document|
      score = keyword_score(document)
      [ document, score ] if score.positive?
    end

    scored_documents
      .sort_by { |(_document, score)| -score }
      .first(MAX_RETRIEVAL_RESULTS)
  end

  def keyword_score(document)
    document_text = [
      document.title,
      document.category,
      document.body,
      document.extracted_text
    ].compact.join(" ").downcase

    message_terms.count { |term| document_text.include?(term) }
  end

  def message_terms
    @message_terms ||= message.body.downcase.scan(/[a-z0-9]+/).reject { |term| term.length < 4 }.uniq
  end

  def record_retrieval_results(retrieved_documents)
    retrieved_documents.map.with_index(1) do |(document, score), rank|
      RetrievalResult.create!(
        message: message,
        knowledge_document: document,
        score: score,
        rank: rank
      )
    end
  end

  def create_response_draft!(bot_output)
    conversation.response_drafts.create!(
      bot_agent: bot_agent,
      body: bot_output.fetch(:body),
      status: bot_output.fetch(:status),
      confidence: bot_output.fetch(:confidence),
      category: bot_output.fetch(:category),
      review_reason: bot_output[:review_reason],
      upload_requested: bot_output.fetch(:upload_requested, false),
      upload_type: bot_output[:upload_type],
      raw_provider_response: bot_output.fetch(:raw_provider_response)
    )
  end

  def review_required?(response_draft)
    response_draft.confidence < confidence_threshold || response_draft.status == "pending_review"
  end

  def request_operator_review!(response_draft)
    conversation.update!(
      status: "pending_operator_review",
      operator_review_requested_at: Time.current
    )

    response_draft.response_reviews.create!(
      conversation: conversation,
      status: "pending",
      key_decision: "response_publication",
      reason: response_draft.review_reason.presence || "Confidence is below the configured threshold.",
      summary: "Review the proposed support response before it is sent to the customer."
    )
  end

  def publish_bot_message!(response_draft)
    conversation.publish_support_message!(
      body: response_draft.body,
      origin: "bot_auto_sent",
      author: bot_agent,
      published_by: bot_agent,
      response_draft: response_draft
    ).tap do
      response_draft.update!(status: "published")
    end
  end
end
