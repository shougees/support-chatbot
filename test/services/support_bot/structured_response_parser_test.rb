require "test_helper"

module SupportBot
  class StructuredResponseParserTest < ActiveSupport::TestCase
    test "parses valid structured response and normalizes confidence" do
      response = StructuredResponseParser.call(valid_payload(confidence: 0.83))

      assert_equal "We can help track the order.", response.body
      assert_equal 83, response.confidence
      assert_equal "order_status", response.category
      assert_equal [ "doc-1" ], response.source_references
      assert_equal "draft", response.status
      assert_not response.upload_requested
      assert_not response.escalation_recommended
      assert_not response.failure?
    end

    test "accepts confidence already expressed as a percentage" do
      response = StructuredResponseParser.call(valid_payload(confidence: 74.25))

      assert_equal 74.25, response.confidence
    end

    test "parses upload request fields" do
      response = StructuredResponseParser.call(
        valid_payload(
          upload_requested: true,
          upload_type: "image"
        )
      )

      assert response.upload_requested
      assert_equal "image", response.upload_type
    end

    test "routes escalation recommendation to pending review" do
      response = StructuredResponseParser.call(
        valid_payload(
          confidence: 0.42,
          escalation_recommended: true,
          escalation_reason: "Payment-critical issue needs review."
        )
      )

      assert_equal "pending_review", response.status
      assert response.escalation_recommended
      assert_equal "Payment-critical issue needs review.", response.escalation_reason
      assert_equal response.escalation_reason, response.review_reason
    end

    test "returns failure for invalid json" do
      response = StructuredResponseParser.call("We can help.")

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal "Bot response was not valid JSON.", response.review_reason
    end

    test "returns failure for missing required fields" do
      payload = valid_payload.except("confidence")

      response = StructuredResponseParser.call(payload)

      assert response.failure?
      assert_match "missing required fields", response.review_reason
    end

    test "returns failure for invalid upload type" do
      response = StructuredResponseParser.call(
        valid_payload(
          upload_requested: true,
          upload_type: "spreadsheet"
        )
      )

      assert response.failure?
      assert_equal "Bot response upload_type is invalid.", response.review_reason
    end

    test "returns failure when escalation reason is missing" do
      response = StructuredResponseParser.call(
        valid_payload(
          escalation_recommended: true,
          escalation_reason: nil
        )
      )

      assert response.failure?
      assert_equal "Bot response escalation_reason is required when escalation is recommended.", response.review_reason
    end

    test "returns failure for first-person singular phrasing" do
      [
        "I can help track the order.",
        "I will check the order status.",
        "I found the return policy."
      ].each do |answer_text|
        response = StructuredResponseParser.call(valid_payload(answer_text: answer_text))

        assert response.failure?, "#{answer_text.inspect} should fail tone guardrail"
        assert_equal "pending_review", response.status
        assert_equal "Bot response used disallowed first-person singular phrasing.", response.review_reason
        assert_no_match(/\bI\s+(can|will|found)\b/i, response.body)
      end
    end

    private

    def valid_payload(overrides = {})
      {
        "answer_text" => "We can help track the order.",
        "confidence" => 0.83,
        "category" => "order_status",
        "source_references" => [ "doc-1" ],
        "upload_requested" => false,
        "upload_type" => nil,
        "escalation_recommended" => false,
        "escalation_reason" => nil
      }.merge(overrides.stringify_keys)
    end
  end
end
