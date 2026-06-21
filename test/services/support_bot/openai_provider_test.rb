require "test_helper"

module SupportBot
  class OpenaiProviderTest < ActiveSupport::TestCase
    test "reads api key from environment" do
      with_env("OPENAI_API_KEY" => "env-api-key") do
        assert_equal "env-api-key", OpenaiProvider.api_key
      end
    end

    test "sends response request payload to OpenAI client" do
      client = CapturingClient.new(
        "_http_status" => 200,
        "output_text" => JSON.generate(
          answer_text: "We checked the order status.",
          confidence: 0.81,
          category: "order_status",
          source_references: [ "policy-1" ],
          upload_requested: false,
          upload_type: nil,
          escalation_recommended: false,
          escalation_reason: nil
        )
      )
      provider = OpenaiProvider.new(client: client, api_key: "test-key")

      response = provider.call(provider_request)

      assert_equal "We checked the order status.", response.body
      assert_equal "draft", response.status
      assert_equal 81, response.confidence
      assert_equal "order_status", response.category
      assert_equal [ "policy-1" ], response.source_references
      assert_equal "test-key", client.api_key
      assert_equal bot_agents(:support_bot).llm_model, client.payload.fetch(:model)
      assert_match "Use 'we'", client.payload.fetch(:instructions)
      assert_match "Do not tell the customer that a human, agent, or operator is helping behind the scenes", client.payload.fetch(:instructions)
      assert_match "When escalation_recommended is true", client.payload.fetch(:instructions)
      assert_match "Return only valid JSON", client.payload.fetch(:instructions)
      assert_match "Customer support request", client.payload.fetch(:input)
      assert_not response.failure?
    end

    test "uses controlled failure when OpenAI text is not structured JSON" do
      client = CapturingClient.new(
        "_http_status" => 200,
        "output_text" => "We can help with that."
      )
      provider = OpenaiProvider.new(client: client, api_key: "test-key")

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal "Bot response was not valid JSON.", response.review_reason
    end

    test "uses controlled failure when api key is missing" do
      provider = OpenaiProvider.new(client: CapturingClient.new, api_key: nil)

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal 0, response.confidence
      assert_equal "OpenAI API key is not configured.", response.review_reason
    end

    test "uses controlled failure for non-success http response" do
      client = CapturingClient.new(
        "_http_status" => 429,
        "error" => { "message" => "rate limited" }
      )
      provider = OpenaiProvider.new(client: client, api_key: "test-key")

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal "rate limited", response.review_reason
    end

    test "uses controlled failure for client exceptions" do
      provider = OpenaiProvider.new(client: FailingClient.new, api_key: "test-key")

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "OpenAI provider call failed.", response.review_reason
      assert_match "RuntimeError", response.raw_provider_response
    end

    private

    def provider_request
      conversation = conversations(:open_conversation)
      message = conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))

      ProviderRequest.new(
        conversation: conversation,
        message: message,
        bot_agent: bot_agents(:support_bot),
        retrieved_documents: [ knowledge_documents(:refund_policy) ]
      )
    end

    def with_env(values)
      previous_values = values.transform_values { |_value| nil }
      values.each do |key, value|
        previous_values[key] = ENV[key]
        ENV[key] = value
      end

      yield
    ensure
      previous_values.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end

    class CapturingClient
      attr_reader :api_key, :payload

      def initialize(response = {})
        @response = response
      end

      def post_response(api_key:, payload:)
        @api_key = api_key
        @payload = payload
        @response
      end
    end

    class FailingClient
      def post_response(api_key:, payload:)
        raise "network unavailable"
      end
    end
  end
end
