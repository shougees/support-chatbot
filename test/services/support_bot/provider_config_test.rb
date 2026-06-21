require "test_helper"

module SupportBot
  class ProviderConfigTest < ActiveSupport::TestCase
    test "openai profile reads key from environment and defaults base url" do
      with_env("OPENAI_API_KEY" => "env-openai-key", "OPENAI_BASE_URL" => nil) do
        profile = ProviderConfig.for("openai", bot_agent: bot_agents(:support_bot))

        assert_equal "openai", profile.name
        assert_equal "OpenAI", profile.label
        assert_equal "env-openai-key", profile.api_key
        assert_equal ProviderConfig::OPENAI_DEFAULT_BASE_URL, profile.base_url
        assert_equal bot_agents(:support_bot).llm_model, profile.model
      end
    end

    test "openai_compatible profile reads generic configuration from environment" do
      with_env("LLM_API_KEY" => "env-api-key", "LLM_BASE_URL" => "https://example.test/v1", "LLM_MODEL" => "provider/model") do
        profile = ProviderConfig.for("openai_compatible")

        assert_equal "openai_compatible", profile.name
        assert_equal "LLM", profile.label
        assert_equal "env-api-key", profile.api_key
        assert_equal "https://example.test/v1", profile.base_url
        assert_equal "provider/model", profile.model
      end
    end

    test "openai_compatible profile supports the Fireworks api key alias" do
      with_env("LLM_API_KEY" => nil, "FIREWORKS_API_KEY" => "fireworks-key") do
        assert_equal "fireworks-key", ProviderConfig.for("openai_compatible").api_key
      end
    end

    test "openai_compatible profile falls back to provider defaults" do
      with_env(
        "LLM_API_KEY" => nil, "FIREWORKS_API_KEY" => nil,
        "LLM_BASE_URL" => nil, "FIREWORKS_BASE_URL" => nil, "LLM_MODEL" => nil
      ) do
        profile = ProviderConfig.for("openai_compatible")

        assert_equal ProviderConfig::COMPATIBLE_DEFAULT_BASE_URL, profile.base_url
        assert_equal ProviderConfig::COMPATIBLE_DEFAULT_MODEL, profile.model
      end
    end

    test "openai_compatible profile uses the bot agent model only for matching providers" do
      with_env("LLM_MODEL" => nil) do
        profile = ProviderConfig.for("openai_compatible", bot_agent: bot_agents(:support_bot))

        # support_bot fixture is provider: openai, so its model is ignored here.
        assert_equal ProviderConfig::COMPATIBLE_DEFAULT_MODEL, profile.model
      end
    end

    private

    def with_env(values)
      previous = {}
      values.each do |key, value|
        previous[key] = ENV[key]
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end

      yield
    ensure
      previous.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
  end
end
