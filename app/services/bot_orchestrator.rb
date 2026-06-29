class BotOrchestrator
  DEFAULT_CONFIDENCE_THRESHOLD = 70
  MAX_RETRIEVAL_RESULTS = 3

  Result = Struct.new(:response_draft, :message, :response_review, :retrieval_results, :agent_decision_trace, keyword_init: true) do
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
    log_retrieval_miss if retrieved_document_matches.empty?
    retrieval_results = record_retrieval_results(retrieved_document_matches)
    provider_request = SupportBot::ProviderRequest.new(
      conversation: conversation,
      message: message,
      bot_agent: bot_agent,
      retrieved_documents: retrieved_document_matches.map(&:document)
    )
    bot_output = provider.call(provider_request).to_h
    log_provider_failure(bot_output[:failure_reason]) if bot_output[:failure_reason].present?

    proposed_actions = bot_output.fetch(:proposed_actions, [])

    ResponseDraft.transaction do
      response_draft = create_response_draft!(bot_output, proposed_actions, retrieved_document_matches)

      if review_required?(response_draft, proposed_actions)
        response_review = request_operator_review!(response_draft)
        record_proposed_actions!(response_review, proposed_actions)
        agent_decision_trace = create_agent_decision_trace!(
          bot_output: bot_output,
          response_draft: response_draft,
          response_review: response_review,
          retrieved_document_matches: retrieved_document_matches,
          proposed_actions: proposed_actions
        )

        Result.new(
          response_draft: response_draft,
          response_review: response_review,
          retrieval_results: retrieval_results,
          agent_decision_trace: agent_decision_trace
        )
      else
        published_message = publish_bot_message!(response_draft)
        agent_decision_trace = create_agent_decision_trace!(
          bot_output: bot_output,
          response_draft: response_draft,
          published_message: published_message,
          retrieved_document_matches: retrieved_document_matches,
          proposed_actions: proposed_actions
        )

        Result.new(
          response_draft: response_draft,
          message: published_message,
          retrieval_results: retrieval_results,
          agent_decision_trace: agent_decision_trace
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

  def create_response_draft!(bot_output, proposed_actions, retrieved_document_matches)
    primary_action = proposed_actions.first

    conversation.response_drafts.create!(
      bot_agent: bot_agent,
      body: bot_output.fetch(:body),
      status: bot_output.fetch(:status),
      confidence: bot_output.fetch(:confidence),
      category: bot_output.fetch(:category),
      review_reason: bot_output[:review_reason],
      upload_requested: bot_output.fetch(:upload_requested, false),
      upload_type: bot_output[:upload_type],
      proposed_action_type: primary_action && primary_action[:action_type],
      proposed_action_payload: primary_action && primary_action.to_json,
      raw_provider_response: bot_output.fetch(:raw_provider_response),
      metadata: response_metadata(bot_output, retrieved_document_matches).to_json
    )
  end

  def response_metadata(bot_output, retrieved_document_matches)
    {
      source_references: bot_output.fetch(:source_references, []),
      escalation_recommended: bot_output.fetch(:escalation_recommended, false),
      escalation_reason: bot_output[:escalation_reason],
      failure_reason: bot_output[:failure_reason],
      retrieval: retrieval_metadata(retrieved_document_matches)
    }.compact
  end

  def retrieval_metadata(retrieved_document_matches)
    {
      query: message.body,
      result_count: retrieved_document_matches.size,
      status: retrieved_document_matches.any? ? "matched" : "no_matches",
      source_identifiers: retrieved_document_matches.map { |result| result.document.source_identifier }.compact
    }
  end

  # Persists each model-proposed sensitive action as a `proposed` SupportAction
  # for operator review. The model proposes; application code and operators
  # decide whether the action is eligible (see PRD action boundaries).
  def record_proposed_actions!(response_review, proposed_actions)
    proposed_actions.each do |action|
      action_type = action[:action_type]
      next unless SupportAction::ACTION_TYPES.include?(action_type)

      conversation.support_actions.create!(
        message: message,
        response_review: response_review,
        action_type: action_type,
        status: "proposed",
        eligibility_reason: action.dig(:arguments, "reason"),
        metadata: action.to_json
      )
    end
  end

  # Any model-proposed sensitive action forces review, independent of
  # confidence or status. This keeps the action boundary enforced at the
  # persistence layer rather than relying on the provider to also flag the
  # response as low-confidence/pending.
  def review_required?(response_draft, proposed_actions = [])
    proposed_actions.any? ||
      response_draft.confidence < confidence_threshold ||
      response_draft.status == "pending_review"
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
      summary: review_summary_for(response_draft)
    )
  end

  def review_summary_for(response_draft)
    metadata = response_draft.metadata_hash
    return "Automatic response generation failed; review the fallback before replying." if metadata["failure_reason"].present?
    return "No matching knowledge document was found; review the proposed response for policy coverage." if metadata.dig("retrieval", "status") == "no_matches"

    "Review the proposed support response before it is sent to the customer."
  end

  def create_agent_decision_trace!(bot_output:, response_draft:, retrieved_document_matches:, proposed_actions:, response_review: nil, published_message: nil)
    message.create_agent_decision_trace!(
      conversation: conversation,
      bot_agent: bot_agent,
      response_draft: response_draft,
      response_review: response_review,
      published_message: published_message,
      outcome: trace_outcome(bot_output, response_draft, response_review, proposed_actions),
      provider_name: bot_agent&.provider || provider.class.name.underscore,
      provider_model: bot_agent&.llm_model,
      response_category: response_draft.category,
      confidence: response_draft.confidence,
      review_status: response_review&.status,
      review_required: response_review.present?,
      retrieved_knowledge_document_ids: retrieved_document_matches.map { |result| result.document.id }.to_json,
      proposed_tool_names: proposed_actions.map { |action| action[:name] }.compact.to_json,
      proposed_action_types: proposed_actions.map { |action| action[:action_type] }.compact.to_json,
      metadata: trace_metadata(bot_output, response_draft, retrieved_document_matches, response_review).to_json
    )
  end

  def trace_outcome(bot_output, response_draft, response_review, proposed_actions)
    return "fallback" if bot_output[:failure_reason].present? || response_draft.category == "fallback"
    return "action_proposed" if proposed_actions.any?
    return "upload_requested" if response_draft.upload_requested?
    return "human_review_requested" if response_review.present?

    "answered_directly"
  end

  def trace_metadata(bot_output, response_draft, retrieved_document_matches, response_review)
    {
      customer_message_id: message.id,
      customer_message_body: message.body,
      retrieval: retrieval_metadata(retrieved_document_matches),
      review_reason: response_draft.review_reason,
      review_summary: response_review&.summary,
      escalation_recommended: bot_output.fetch(:escalation_recommended, false),
      escalation_reason: bot_output[:escalation_reason],
      failure_reason: bot_output[:failure_reason],
      upload_type: response_draft.upload_type
    }.compact
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

  def log_retrieval_miss
    Rails.logger.info(
      "[BotOrchestrator] No knowledge matches for conversation_id=#{conversation.id} message_id=#{message.id}"
    )
  end

  def log_provider_failure(failure_reason)
    Rails.logger.warn(
      "[BotOrchestrator] Provider fallback for conversation_id=#{conversation.id} message_id=#{message.id}: #{failure_reason}"
    )
  end
end
