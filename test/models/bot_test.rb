require "test_helper"

class BotTest < ActiveSupport::TestCase
  # Validations

  test "valid with required attributes" do
    bot = Bot.new(name: "Test Bot", provider: "openai", llm_model: "gpt-4o")
    assert bot.valid?
  end

  test "invalid without name" do
    bot = Bot.new(provider: "openai", llm_model: "gpt-4o")
    assert_not bot.valid?
    assert_includes bot.errors[:name], "can't be blank"
  end

  test "invalid without provider" do
    bot = Bot.new(name: "Test Bot", provider: nil, llm_model: "gpt-4o")
    assert_not bot.valid?
    assert_includes bot.errors[:provider], "can't be blank"
  end

  test "invalid without llm_model" do
    bot = Bot.new(name: "Test Bot", provider: "openai", llm_model: nil)
    assert_not bot.valid?
    assert_includes bot.errors[:llm_model], "can't be blank"
  end

  test "invalid with unknown provider" do
    bot = Bot.new(name: "Test Bot", provider: "unknown", llm_model: "gpt-4o")
    assert_not bot.valid?
    assert_includes bot.errors[:provider], "is not included in the list"
  end

  # Scopes

  test ".active returns only active bots" do
    active_bots = Bot.active
    assert active_bots.all?(&:active?)
    assert_includes active_bots, bots(:support_bot)
    assert_not_includes active_bots, bots(:inactive_bot)
  end

  # Class methods

  test ".current returns the active bot" do
    assert_equal bots(:support_bot), Bot.current
  end

  test ".current returns nil when no active bot exists" do
    Bot.update_all(active: false)
    assert_nil Bot.current
  end

  # Fixtures

  test "support_bot fixture is valid and active" do
    bot = bots(:support_bot)
    assert bot.valid?
    assert bot.active?
    assert_equal "openai", bot.provider
    assert_equal "gpt-4o", bot.llm_model
  end

  test "inactive_bot fixture is valid and inactive" do
    bot = bots(:inactive_bot)
    assert bot.valid?
    assert_not bot.active?
  end
end
