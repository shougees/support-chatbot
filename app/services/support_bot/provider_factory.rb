module SupportBot
  class ProviderFactory
    def self.build(bot_agent:)
      new(bot_agent:).build
    end

    def initialize(bot_agent:, force_fake_in_test: Rails.env.test?)
      @bot_agent = bot_agent
      @force_fake_in_test = force_fake_in_test
    end

    def build
      return FakeProvider.new if force_fake_in_test

      case configured_provider
      when "openai", "openai_compatible", "fireworks"
        LlmProvider.new(config: ProviderConfig.for(configured_provider, bot_agent: bot_agent))
      else
        FakeProvider.new
      end
    end

    private

    attr_reader :bot_agent, :force_fake_in_test

    def configured_provider
      ENV["SUPPORT_BOT_PROVIDER"].presence || bot_agent&.provider.presence || default_provider_mode
    end

    def default_provider_mode
      Rails.env.production? ? "openai" : "fake"
    end
  end
end
