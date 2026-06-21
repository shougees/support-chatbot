module SupportBot
  # Single source of truth for the structured chatbot response contract.
  #
  # The same response shape used to be redeclared inside every provider
  # (`structured_response_instructions`) and again inside the parser. It now
  # lives here once: the prompt builder uses {.instructions} to tell the model
  # what to return, and {StructuredResponseParser} uses {REQUIRED_KEYS} /
  # {UPLOAD_TYPES} to validate what came back.
  module ResponseContract
    REQUIRED_KEYS = %w[
      answer_text
      confidence
      category
      source_references
      upload_requested
      upload_type
      escalation_recommended
      escalation_reason
    ].freeze

    # Anchored to the persistence model so the valid set of upload types is
    # defined exactly once across the LLM contract and the database column.
    UPLOAD_TYPES = ResponseDraft::UPLOAD_TYPES

    module_function

    def instructions
      <<~INSTRUCTIONS
        Return only valid JSON with this exact shape:
        {
          "answer_text": "customer-facing support reply",
          "confidence": 0.0,
          "category": "short_category",
          "source_references": ["knowledge-document-id"],
          "upload_requested": false,
          "upload_type": null,
          "escalation_recommended": false,
          "escalation_reason": null
        }
        Confidence must be between 0 and 1.
        upload_type must be "image", "document", "either", or null.
        escalation_reason is required when escalation_recommended is true.
      INSTRUCTIONS
    end
  end
end
