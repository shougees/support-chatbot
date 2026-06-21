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

    test "can select OpenAI compatible provider outside test environment" do
      with_env("SUPPORT_BOT_PROVIDER", "openai_compatible") do
        provider = ProviderFactory.new(bot_agent: bot_agents(:support_bot), force_fake_in_test: false).build

        assert_instance_of OpenaiCompatibleChatProvider, provider
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
