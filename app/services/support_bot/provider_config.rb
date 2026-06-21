module SupportBot
  # Resolves connection settings (api key, base url, model) for the unified
  # {LlmProvider} from a named profile, the environment, and the active bot
  # agent. This consolidates the per-provider `self.api_key/base_url/model`
  # class methods that previously lived on each provider.
  #
  # Both profiles speak the same OpenAI-compatible chat-completions wire
  # format; they only differ in their default endpoint and credential lookup.
  class ProviderConfig
    Profile = Struct.new(:name, :api_key, :base_url, :model, keyword_init: true) do
      def label
        name == "openai" ? "OpenAI" : "LLM"
      end
    end

    OPENAI_DEFAULT_BASE_URL = "https://api.openai.com/v1".freeze
    OPENAI_DEFAULT_MODEL = "gpt-4.1-mini".freeze
    COMPATIBLE_DEFAULT_BASE_URL = "https://api.fireworks.ai/inference/v1".freeze
    COMPATIBLE_DEFAULT_MODEL = "accounts/fireworks/models/kimi-k2.6".freeze

    def self.for(profile_name, bot_agent: nil)
      case profile_name.to_s
      when "openai"
        openai(bot_agent)
      else
        openai_compatible(bot_agent)
      end
    end

    def self.openai(bot_agent = nil)
      Profile.new(
        name: "openai",
        api_key: ENV["OPENAI_API_KEY"].presence || credentials.dig(:openai, :api_key),
        base_url: ENV["OPENAI_BASE_URL"].presence || OPENAI_DEFAULT_BASE_URL,
        model: bot_agent&.llm_model.presence || OPENAI_DEFAULT_MODEL
      )
    end

    def self.openai_compatible(bot_agent = nil)
      Profile.new(
        name: "openai_compatible",
        api_key: ENV["LLM_API_KEY"].presence || ENV["FIREWORKS_API_KEY"].presence ||
          credentials.dig(:llm, :api_key) || credentials.dig(:fireworks, :api_key),
        base_url: ENV["LLM_BASE_URL"].presence || ENV["FIREWORKS_BASE_URL"].presence || COMPATIBLE_DEFAULT_BASE_URL,
        model: ENV["LLM_MODEL"].presence || compatible_bot_model(bot_agent) || COMPATIBLE_DEFAULT_MODEL
      )
    end

    def self.compatible_bot_model(bot_agent)
      return unless bot_agent&.provider == "openai_compatible"

      bot_agent.llm_model.presence
    end

    def self.credentials
      Rails.application.credentials
    end
    private_class_method :credentials
  end
end
