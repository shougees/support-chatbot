require "test_helper"

module SupportBot
  class ProviderFactoryTest < ActiveSupport::TestCase
    test "uses fake provider by default outside production" do
      with_env("SUPPORT_BOT_PROVIDER", nil) do
        provider = ProviderFactory.build(bot_agent: bot_agents(:support_bot))

        assert_instance_of FakeProvider, provider
      end
    end

    test "uses fake provider in test even when OpenAI is explicitly enabled" do
      with_env("SUPPORT_BOT_PROVIDER", "openai") do
        provider = ProviderFactory.build(bot_agent: bot_agents(:support_bot))

        assert_instance_of FakeProvider, provider
      end
    end

    test "builds the unified LLM provider for openai_compatible outside test" do
      with_env("SUPPORT_BOT_PROVIDER", "openai_compatible") do
        provider = ProviderFactory.new(bot_agent: bot_agents(:support_bot), force_fake_in_test: false).build

        assert_instance_of LlmProvider, provider
      end
    end

    test "builds the unified LLM provider for openai outside test" do
      with_env("SUPPORT_BOT_PROVIDER", "openai") do
        provider = ProviderFactory.new(bot_agent: bot_agents(:support_bot), force_fake_in_test: false).build

        assert_instance_of LlmProvider, provider
      end
    end

    test "builds the unified LLM provider for fireworks outside test" do
      with_env("SUPPORT_BOT_PROVIDER", "fireworks") do
        provider = ProviderFactory.new(bot_agent: bot_agents(:fireworks_bot), force_fake_in_test: false).build

        assert_instance_of LlmProvider, provider
      end
    end

    private

    def with_env(key, value = nil)
      previous_value = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value

      yield
    ensure
      previous_value.nil? ? ENV.delete(key) : ENV[key] = previous_value
    end
  end
end
