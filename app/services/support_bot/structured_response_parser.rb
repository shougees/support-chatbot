require "json"

module SupportBot
  class StructuredResponseParser
    # The response shape lives in one place: SupportBot::ResponseContract.
    REQUIRED_KEYS = ResponseContract::REQUIRED_KEYS
    UPLOAD_TYPES = ResponseContract::UPLOAD_TYPES

    def self.call(payload, raw_provider_response: payload)
      new(payload, raw_provider_response: raw_provider_response).call
    end

    def initialize(payload, raw_provider_response:)
      @payload = payload
      @raw_provider_response = raw_provider_response
    end

    def call
      attributes = parse_payload
      missing_keys = REQUIRED_KEYS.reject { |key| attributes.key?(key) }
      return failure("Bot response is missing required fields: #{missing_keys.to_sentence}.") if missing_keys.any?

      validation_error = validate(attributes)
      return failure(validation_error) if validation_error.present?

      ProviderResponse.new(
        body: attributes.fetch("answer_text").to_s,
        confidence: normalize_confidence(attributes.fetch("confidence")),
        category: attributes.fetch("category").to_s,
        status: truthy?(attributes.fetch("escalation_recommended")) ? "pending_review" : "draft",
        review_reason: attributes["escalation_reason"].presence,
        upload_requested: truthy?(attributes.fetch("upload_requested")),
        upload_type: attributes["upload_type"].presence,
        source_references: attributes.fetch("source_references"),
        escalation_recommended: truthy?(attributes.fetch("escalation_recommended")),
        escalation_reason: attributes["escalation_reason"].presence,
        raw_provider_response: raw_provider_response_text
      )
    rescue JSON::ParserError
      failure("Bot response was not valid JSON.")
    end

    private

    attr_reader :payload, :raw_provider_response

    def parse_payload
      case payload
      when Hash
        payload.deep_stringify_keys
      else
        JSON.parse(payload.to_s)
      end
    end

    def validate(attributes)
      return "Bot response answer text is blank." if attributes["answer_text"].blank?
      return "Bot response confidence is invalid." unless valid_confidence?(attributes["confidence"])
      return "Bot response category is blank." if attributes["category"].blank?
      return "Bot response source references must be an array." unless attributes["source_references"].is_a?(Array)
      return "Bot response upload_requested must be true or false." unless booleanish?(attributes["upload_requested"])
      return "Bot response escalation_recommended must be true or false." unless booleanish?(attributes["escalation_recommended"])
      return "Bot response upload_type is required when upload is requested." if truthy?(attributes["upload_requested"]) && attributes["upload_type"].blank?
      return "Bot response upload_type is invalid." if attributes["upload_type"].present? && UPLOAD_TYPES.exclude?(attributes["upload_type"])
      return "Bot response escalation_reason is required when escalation is recommended." if truthy?(attributes["escalation_recommended"]) && attributes["escalation_reason"].blank?

      nil
    end

    def failure(reason)
      ProviderResponse.failure(reason, raw_provider_response: raw_provider_response_text)
    end

    def valid_confidence?(value)
      normalized = Float(value)
      normalized.between?(0, 1) || normalized.between?(0, 100)
    rescue ArgumentError, TypeError
      false
    end

    def normalize_confidence(value)
      number = Float(value)
      number <= 1 ? (number * 100).round(2) : number.round(2)
    end

    def booleanish?(value)
      value == true || value == false
    end

    def truthy?(value)
      value == true
    end

    def raw_provider_response_text
      raw_provider_response.is_a?(String) ? raw_provider_response : JSON.generate(raw_provider_response)
    end
  end
end
