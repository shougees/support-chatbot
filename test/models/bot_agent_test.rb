require "test_helper"

class BotAgentTest < ActiveSupport::TestCase
  # Validations

  test "valid with required attributes" do
    bot_agent = BotAgent.new(name: "Test Bot", provider: "openai", llm_model: "gpt-4o")
    assert bot_agent.valid?
  end

  test "invalid without name" do
    bot_agent = BotAgent.new(provider: "openai", llm_model: "gpt-4o")
    assert_not bot_agent.valid?
    assert_includes bot_agent.errors[:name], "can't be blank"
  end

  test "invalid without provider" do
    bot_agent = BotAgent.new(name: "Test Bot", provider: nil, llm_model: "gpt-4o")
    assert_not bot_agent.valid?
    assert_includes bot_agent.errors[:provider], "can't be blank"
  end

  test "invalid without llm_model" do
    bot_agent = BotAgent.new(name: "Test Bot", provider: "openai", llm_model: nil)
    assert_not bot_agent.valid?
    assert_includes bot_agent.errors[:llm_model], "can't be blank"
  end

  test "invalid with unknown provider" do
    bot_agent = BotAgent.new(name: "Test Bot", provider: "unknown", llm_model: "gpt-4o")
    assert_not bot_agent.valid?
    assert_includes bot_agent.errors[:provider], "is not included in the list"
  end

  test "valid with openai compatible provider" do
    bot_agent = BotAgent.new(
      name: "Fireworks Bot",
      provider: "openai_compatible",
      llm_model: "accounts/fireworks/models/kimi-k2.6"
    )

    assert bot_agent.valid?
  end

  # Scopes

  test ".active returns only active bots" do
    active_bot_agents = BotAgent.active
    assert active_bot_agents.all?(&:active?)
    assert_includes active_bot_agents, bot_agents(:support_bot)
    assert_not active_bot_agents.include?(bot_agents(:inactive_bot))
  end

  # Class methods

  test ".current returns the active bot" do
    assert_equal bot_agents(:support_bot), BotAgent.current
  end

  test ".current returns nil when no active bot exists" do
    BotAgent.update_all(active: false)
    assert_nil BotAgent.current
  end

  # Fixtures

  test "support_bot fixture is valid and active" do
    bot_agent = bot_agents(:support_bot)
    assert bot_agent.valid?
    assert bot_agent.active?
    assert_equal "openai", bot_agent.provider
    assert_equal "gpt-4o", bot_agent.llm_model
  end

  test "inactive_bot fixture is valid and inactive" do
    bot_agent = bot_agents(:inactive_bot)
    assert bot_agent.valid?
    assert_not bot_agent.active?
  end

  test "has response drafts" do
    assert_includes bot_agents(:support_bot).response_drafts, response_drafts(:standard_response)
  end
end
