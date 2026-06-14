require "test_helper"

class BotResponseTest < ActiveSupport::TestCase
  test "valid with required fields" do
    message = Message.create!(
      conversation: conversations(:open_conversation),
      role: "assistant",
      body: "We can help with that."
    )
    response = BotResponse.new(message: message, confidence: 72.5)

    assert response.valid?
  end

  test "belongs to assistant message" do
    response = bot_responses(:standard_response)

    assert_equal messages(:assistant_message), response.message
  end

  test "message must be unique" do
    response = BotResponse.new(message: messages(:assistant_message), confidence: 80)

    assert_not response.valid?
    assert_includes response.errors[:message_id], "has already been taken"
  end

  test "requires confidence between zero and one hundred" do
    response = bot_responses(:standard_response)
    response.confidence = 101

    assert_not response.valid?
    assert_includes response.errors[:confidence], "must be less than or equal to 100"
  end

  test "requires assistant message" do
    response = BotResponse.new(message: messages(:user_message), confidence: 80)

    assert_not response.valid?
    assert_includes response.errors[:message], "must be an assistant message"
  end

  test "upload type must be valid when present" do
    response = bot_responses(:review_recommended_response)
    response.upload_type = "spreadsheet"

    assert_not response.valid?
    assert_includes response.errors[:upload_type], "is not included in the list"
  end

  test "low confidence scope uses configurable threshold" do
    assert_includes BotResponse.low_confidence(70), bot_responses(:review_recommended_response)
    assert_not BotResponse.low_confidence(70).include?(bot_responses(:standard_response))
  end

  test "human review recommended scope returns flagged responses" do
    assert_equal [ bot_responses(:review_recommended_response) ], BotResponse.human_review_recommended.to_a
  end
end
