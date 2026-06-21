module SupportBot
  class OpenaiProvider
    DEFAULT_MODEL = "gpt-4.1-mini"

    def initialize(client: OpenaiHttpClient.new, api_key: self.class.api_key)
      @client = client
      @api_key = api_key
    end

    def self.api_key
      ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.dig(:openai, :api_key)
    end

    def call(request)
      return ProviderResponse.failure("OpenAI API key is not configured.", raw_provider_response: "missing_openai_api_key") if api_key.blank?

      raw_response = client.post_response(
        api_key: api_key,
        payload: payload_for(request)
      )

      return http_failure(raw_response) unless raw_response.fetch("_http_status").between?(200, 299)

      text = extract_text(raw_response)
      return ProviderResponse.failure("OpenAI response did not include answer text.", raw_provider_response: raw_response.to_json) if text.blank?

      StructuredResponseParser.call(text, raw_provider_response: raw_response)
    rescue JSON::ParserError => error
      ProviderResponse.failure("OpenAI returned invalid JSON.", raw_provider_response: "#{error.class}: #{error.message}")
    rescue StandardError => error
      ProviderResponse.failure("OpenAI provider call failed.", raw_provider_response: "#{error.class}: #{error.message}")
    end

    private

    attr_reader :client, :api_key

    def payload_for(request)
      {
        model: request.bot_agent&.llm_model.presence || DEFAULT_MODEL,
        instructions: instructions_for(request),
        input: request.prompt_text
      }
    end

    def instructions_for(request)
      [
        request.bot_agent&.system_prompt,
        "Use concise ecommerce support language.",
        "Use 'we' instead of first-person singular language.",
        "Do not claim that a real refund, return, account, or delivery action was completed.",
        "If policy or context is insufficient, set escalation_recommended to true.",
        structured_response_instructions
      ].compact.join("\n")
    end

    def structured_response_instructions
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

    def extract_text(raw_response)
      raw_response["output_text"].presence || raw_response.fetch("output", []).filter_map do |item|
        next unless item["type"] == "message"

        item.fetch("content", []).filter_map { |content| content["text"] || content.dig("text", "value") }.join
      end.join
    end

    def http_failure(raw_response)
      message = raw_response.dig("error", "message").presence || "OpenAI provider returned HTTP #{raw_response.fetch("_http_status")}."
      ProviderResponse.failure(message, raw_provider_response: raw_response.to_json)
    end
  end
end
