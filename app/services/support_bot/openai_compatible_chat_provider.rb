module SupportBot
  class OpenaiCompatibleChatProvider
    DEFAULT_BASE_URL = "https://api.fireworks.ai/inference/v1"
    DEFAULT_MODEL = "accounts/fireworks/models/kimi-k2.6"

    def initialize(client: OpenaiCompatibleChatClient.new, api_key: self.class.api_key, base_url: self.class.base_url, model: self.class.model)
      @client = client
      @api_key = api_key
      @base_url = base_url
      @model = model
    end

    def self.api_key
      ENV["LLM_API_KEY"].presence ||
        ENV["FIREWORKS_API_KEY"].presence ||
        Rails.application.credentials.dig(:llm, :api_key) ||
        Rails.application.credentials.dig(:fireworks, :api_key)
    end

    def self.base_url
      ENV["LLM_BASE_URL"].presence || ENV["FIREWORKS_BASE_URL"].presence || DEFAULT_BASE_URL
    end

    def self.model
      ENV["LLM_MODEL"].presence || DEFAULT_MODEL
    end

    def call(request)
      return ProviderResponse.failure("LLM API key is not configured.", raw_provider_response: "missing_llm_api_key") if api_key.blank?

      raw_response = client.post_chat_completion(
        api_key: api_key,
        base_url: base_url,
        payload: payload_for(request)
      )

      return http_failure(raw_response) unless raw_response.fetch("_http_status").between?(200, 299)

      text = extract_text(raw_response)
      return ProviderResponse.failure("LLM response did not include answer text.", raw_provider_response: raw_response.to_json) if text.blank?

      StructuredResponseParser.call(text, raw_provider_response: raw_response)
    rescue JSON::ParserError => error
      ProviderResponse.failure("LLM returned invalid JSON.", raw_provider_response: "#{error.class}: #{error.message}")
    rescue StandardError => error
      ProviderResponse.failure("OpenAI-compatible provider call failed.", raw_provider_response: "#{error.class}: #{error.message}")
    end

    private

    attr_reader :client, :api_key, :base_url, :model

    def payload_for(request)
      {
        model: model_for(request),
        messages: [
          { role: "system", content: instructions_for(request) },
          { role: "user", content: request.prompt_text }
        ],
        temperature: 0.2
      }
    end

    def model_for(request)
      ENV["LLM_MODEL"].presence || openai_compatible_bot_model(request).presence || model
    end

    def openai_compatible_bot_model(request)
      return unless request.bot_agent&.provider == "openai_compatible"

      request.bot_agent.llm_model
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
      content = raw_response.dig("choices", 0, "message", "content")
      return content if content.is_a?(String)

      Array(content).filter_map do |item|
        item["text"] || item.dig("text", "value")
      end.join
    end

    def http_failure(raw_response)
      message = raw_response.dig("error", "message").presence || "LLM provider returned HTTP #{raw_response.fetch("_http_status")}."
      ProviderResponse.failure(message, raw_provider_response: raw_response.to_json)
    end
  end
end
