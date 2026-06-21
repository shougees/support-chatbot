module SupportBot
  class FakeProvider
    def call(request)
      return ProviderResponse.failure("No active bot agent is configured.", raw_provider_response: "fake_missing_bot_agent") if request.bot_agent.blank?

      body = request.message.body.downcase

      if body.match?(/agent|human|representative|lawyer|legal|fraud|chargeback|identity|emergency/)
        review_response("This request needs operator review before support replies.", "High-risk or operator-request context detected.")
      elsif body.match?(/refund|return|replace|replacement|damaged|broken|missing/)
        if body.match?(/photo|image|picture|damaged|broken/)
          upload_response(request)
        else
          review_response("We can help review the order and determine the next best step.", "Action eligibility requires operator review.")
        end
      else
        success_response(request)
      end
    end

    private

    def success_response(request)
      source_text = request.retrieved_documents.any? ? " We found relevant support guidance to help with this." : ""

      ProviderResponse.new(
        body: "We can help with that.#{source_text}",
        confidence: 82,
        category: "general_support",
        status: "draft",
        upload_requested: false,
        raw_provider_response: "fake_success"
      )
    end

    def upload_response(request)
      source_text = request.retrieved_documents.any? ? " Based on the relevant policy context," : ""

      ProviderResponse.new(
        body: "#{source_text} please upload a clear image so we can review the item condition.",
        confidence: 76,
        category: "damaged_item",
        status: "draft",
        upload_requested: true,
        upload_type: "image",
        raw_provider_response: "fake_upload_request"
      )
    end

    def review_response(body, reason)
      ProviderResponse.new(
        body: body,
        confidence: 62,
        category: "operator_review",
        status: "pending_review",
        review_reason: reason,
        upload_requested: false,
        raw_provider_response: "fake_operator_review"
      )
    end
  end
end
