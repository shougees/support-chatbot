class BotOrchestrator
  DEFAULT_CONFIDENCE_THRESHOLD = 70
  MAX_RETRIEVAL_RESULTS = 3
  DIRECT_HANDOFF_PATTERN = /\b(agent|human|representative|person|someone)\b/i
  HIGH_RISK_PATTERN = /\b(emergency|safety|unsafe|injury|injured|legal|lawyer|lawsuit|fraud|identity|privacy|chargeback|unauthorized|account locked|payment failed|double charge|policy conflict)\b/i

  Result = Struct.new(:response_draft, :message, :response_review, :retrieval_results, :agent_decision_trace, :escalation, keyword_init: true) do
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

    existing_result = existing_result_for_handled_message
    return existing_result if existing_result.present?

    if high_risk_message?
      return escalate_without_provider!(
        reason: "high_risk",
        summary: "High-risk support issue requires human review.",
        review_reason: "High-risk support issue requires review."
      )
    end

    if direct_handoff_requested?
      return publish_one_more_attempt! if first_direct_handoff_request?

      return escalate_without_provider!(
        reason: "repeated_handoff_request",
        summary: "Customer continues to request human support after one bot attempt.",
        review_reason: "Customer requested human support more than once."
      )
    end

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
        escalation = create_escalation_if_needed!(
          response_draft: response_draft,
          response_review: response_review,
          bot_output: bot_output,
          proposed_actions: proposed_actions
        )
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
          agent_decision_trace: agent_decision_trace,
          escalation: escalation
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

  def existing_result_for_handled_message
    trace = AgentDecisionTrace.find_by(message: message)
    return unless trace

    Result.new(
      response_draft: trace.response_draft,
      message: trace.published_message,
      response_review: trace.response_review,
      retrieval_results: message.retrieval_results.ranked.to_a,
      agent_decision_trace: trace,
      escalation: message.escalations.order(:created_at).first || trace.response_review&.escalation
    )
  end

  def high_risk_message?
    message.body.match?(HIGH_RISK_PATTERN)
  end

  def direct_handoff_requested?
    message.body.match?(DIRECT_HANDOFF_PATTERN)
  end

  def first_direct_handoff_request?
    customer_handoff_request_count <= 1
  end

  def customer_handoff_request_count
    conversation.messages.customer_messages.where("position <= ?", message.position).to_a.count do |customer_message|
      customer_message.body.match?(DIRECT_HANDOFF_PATTERN)
    end
  end

  def publish_one_more_attempt!
    body = "We can help here first. Please share what happened, and we will use the details in this conversation to find the next best step."
    bot_output = {
      body: body,
      confidence: confidence_threshold,
      category: "handoff_retry",
      status: "draft",
      upload_requested: false,
      source_references: [],
      escalation_recommended: false,
      raw_provider_response: "one_more_attempt"
    }

    ResponseDraft.transaction do
      response_draft = create_response_draft!(bot_output, [], [])
      published_message = publish_bot_message!(response_draft)
      agent_decision_trace = create_agent_decision_trace!(
        bot_output: bot_output,
        response_draft: response_draft,
        published_message: published_message,
        retrieved_document_matches: [],
        proposed_actions: []
      )

      Result.new(
        response_draft: response_draft,
        message: published_message,
        retrieval_results: [],
        agent_decision_trace: agent_decision_trace
      )
    end
  end

  def escalate_without_provider!(reason:, summary:, review_reason:)
    bot_output = {
      body: "We are checking this and will reply here.",
      confidence: 0,
      category: reason,
      status: "pending_review",
      review_reason: review_reason,
      upload_requested: false,
      source_references: [],
      escalation_recommended: true,
      escalation_reason: review_reason,
      raw_provider_response: reason
    }

    ResponseDraft.transaction do
      response_draft = create_response_draft!(bot_output, [], [])
      response_review = request_operator_review!(response_draft, summary: summary, reason: review_reason)
      escalation = create_escalation!(
        response_review: response_review,
        reason: reason,
        summary: summary,
        metadata: { routing: "pre_provider", review_reason: review_reason }
      )
      agent_decision_trace = create_agent_decision_trace!(
        bot_output: bot_output,
        response_draft: response_draft,
        response_review: response_review,
        retrieved_document_matches: [],
        proposed_actions: []
      )

      Result.new(
        response_draft: response_draft,
        response_review: response_review,
        retrieval_results: [],
        agent_decision_trace: agent_decision_trace,
        escalation: escalation
      )
    end
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

  def request_operator_review!(response_draft, summary: nil, reason: nil)
    conversation.update!(
      status: "pending_operator_review",
      operator_review_requested_at: Time.current
    )

    response_draft.response_reviews.create!(
      conversation: conversation,
      status: "pending",
      key_decision: "response_publication",
      reason: reason.presence || response_draft.review_reason.presence || "Confidence is below the configured threshold.",
      summary: summary.presence || review_summary_for(response_draft)
    )
  end

  def create_escalation_if_needed!(response_draft:, response_review:, bot_output:, proposed_actions:)
    reason = escalation_reason(response_draft, bot_output, proposed_actions)
    return unless reason

    create_escalation!(
      response_review: response_review,
      reason: reason,
      summary: escalation_summary(reason, response_draft, bot_output),
      metadata: {
        routing: "provider_review",
        confidence: response_draft.confidence,
        category: response_draft.category,
        escalation_recommended: bot_output.fetch(:escalation_recommended, false),
        escalation_reason: bot_output[:escalation_reason],
        proposed_action_types: proposed_actions.map { |action| action[:action_type] }.compact
      }
    )
  end

  def escalation_reason(response_draft, bot_output, proposed_actions)
    return "provider_failure" if bot_output[:failure_reason].present?
    return "action_requires_review" if proposed_actions.any?
    return "low_confidence" if response_draft.confidence < confidence_threshold
    return "policy_review" if bot_output.fetch(:escalation_recommended, false) || response_draft.status == "pending_review"

    nil
  end

  def escalation_summary(reason, response_draft, bot_output)
    return bot_output[:escalation_reason] if bot_output[:escalation_reason].present?
    return response_draft.review_reason if response_draft.review_reason.present?

    case reason
    when "provider_failure"
      "Automatic response generation failed and needs human review."
    when "action_requires_review"
      "A sensitive support action requires human review."
    when "low_confidence"
      "Bot confidence is below the configured threshold."
    else
      "Support response requires human review."
    end
  end

  def create_escalation!(response_review:, reason:, summary:, metadata:)
    conversation.escalations.create!(
      message: message,
      response_review: response_review,
      status: "pending",
      reason: reason,
      summary: summary,
      metadata: metadata.to_json
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
