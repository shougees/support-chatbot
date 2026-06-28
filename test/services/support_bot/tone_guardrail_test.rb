require "test_helper"

module SupportBot
  class ToneGuardrailTest < ActiveSupport::TestCase
    test "allows we voice support language" do
      assert_nil ToneGuardrail.violation_reason("We can help check the order status.")
    end

    test "flags first-person singular support phrases" do
      [
        "I can help with that.",
        "I will check the return policy.",
        "I found the refund guidance.",
        "I'm checking this now.",
        "I've reviewed the order."
      ].each do |text|
        assert_equal "Bot response used disallowed first-person singular phrasing.", ToneGuardrail.violation_reason(text)
      end
    end

    test "provides prompt instructions for model providers" do
      instructions = ToneGuardrail.instructions.join("\n")

      assert_match "Use 'we'", instructions
      assert_match "Do not use first-person singular phrasing", instructions
      assert_match "1-3 short sentences", instructions
      assert_match "clear about limitations", instructions
    end
  end
end
