module SupportBot
  ProviderResponse = Struct.new(
    :body,
    :confidence,
    :category,
    :status,
    :review_reason,
    :upload_requested,
    :upload_type,
    :source_references,
    :escalation_recommended,
    :escalation_reason,
    :raw_provider_response,
    :failure_reason,
    keyword_init: true
  ) do
    def self.failure(reason, raw_provider_response: nil)
      new(
        body: "We need a support operator to review this before replying.",
        confidence: 0,
        category: "fallback",
        status: "pending_review",
        review_reason: reason,
        upload_requested: false,
        source_references: [],
        escalation_recommended: true,
        escalation_reason: reason,
        raw_provider_response: raw_provider_response || reason,
        failure_reason: reason
      )
    end

    def failure?
      failure_reason.present?
    end

    def to_h
      {
        body: body,
        confidence: confidence,
        category: category,
        status: status,
        review_reason: review_reason,
        upload_requested: upload_requested,
        upload_type: upload_type,
        source_references: source_references || [],
        escalation_recommended: escalation_recommended || false,
        escalation_reason: escalation_reason,
        raw_provider_response: raw_provider_response
      }
    end
  end
end
