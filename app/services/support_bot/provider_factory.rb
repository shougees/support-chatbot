module SupportBot
  class ProviderFactory
    def self.build(bot_agent:)
      new(bot_agent:).build
    end

    def initialize(bot_agent:)
      @bot_agent = bot_agent
    end

    def build
      return FakeProvider.new if fake_provider?

      case bot_agent&.provider
      when "openai"
        OpenaiProvider.new
      else
        FakeProvider.new
      end
    end

    private

    attr_reader :bot_agent

    def fake_provider?
      ENV.fetch("SUPPORT_BOT_PROVIDER", default_provider_mode) == "fake"
    end

    def default_provider_mode
      Rails.env.production? ? "openai" : "fake"
    end
  end
end
