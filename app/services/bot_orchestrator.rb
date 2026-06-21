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

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(conversation:, message:, bot_agent: BotAgent.current, confidence_threshold: default_confidence_threshold, provider: nil)
    @conversation = conversation
    @message = message
    @bot_agent = bot_agent
    @confidence_threshold = confidence_threshold.to_f
    @provider = provider || SupportBot::ProviderFactory.build(bot_agent: bot_agent)
  end

  def call
    validate_message!

    retrieved_document_matches = retrieve_documents
    retrieval_results = record_retrieval_results(retrieved_document_matches)
    provider_request = SupportBot::ProviderRequest.new(
      conversation: conversation,
      message: message,
      bot_agent: bot_agent,
      retrieved_documents: retrieved_document_matches.map(&:document)
    )
    bot_output = provider.call(provider_request).to_h

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
    KnowledgeDocumentKeywordRetriever.call(question: message.body, limit: MAX_RETRIEVAL_RESULTS)
  end

  def record_retrieval_results(retrieved_documents)
    retrieved_documents.map.with_index(1) do |result, rank|
      RetrievalResult.create!(
        message: message,
        knowledge_document: result.document,
        score: result.score,
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
      raw_provider_response: bot_output.fetch(:raw_provider_response),
      metadata: {
        source_references: bot_output.fetch(:source_references, []),
        escalation_recommended: bot_output.fetch(:escalation_recommended, false),
        escalation_reason: bot_output[:escalation_reason]
      }.to_json
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
