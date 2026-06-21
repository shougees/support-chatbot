require "test_helper"

module SupportBot
  class OpenaiCompatibleChatProviderTest < ActiveSupport::TestCase
    test "reads generic api configuration from environment" do
      with_env(
        "LLM_API_KEY" => "env-api-key",
        "LLM_BASE_URL" => "https://example.test/v1",
        "LLM_MODEL" => "provider/model"
      ) do
        assert_equal "env-api-key", OpenaiCompatibleChatProvider.api_key
        assert_equal "https://example.test/v1", OpenaiCompatibleChatProvider.base_url
        assert_equal "provider/model", OpenaiCompatibleChatProvider.model
      end
    end

    test "supports Fireworks api key alias" do
      with_env("LLM_API_KEY" => nil, "FIREWORKS_API_KEY" => "fireworks-key") do
        assert_equal "fireworks-key", OpenaiCompatibleChatProvider.api_key
      end
    end

    test "sends chat completion payload to OpenAI compatible client" do
      client = CapturingClient.new(
        "_http_status" => 200,
        "choices" => [
          {
            "message" => {
              "content" => JSON.generate(
                answer_text: "We checked the order status.",
                confidence: 0.79,
                category: "order_status",
                source_references: [ "policy-1" ],
                upload_requested: false,
                upload_type: nil,
                escalation_recommended: false,
                escalation_reason: nil
              )
            }
          }
        ]
      )
      provider = OpenaiCompatibleChatProvider.new(
        client: client,
        api_key: "test-key",
        base_url: "https://example.test/v1",
        model: "accounts/fireworks/models/kimi-k2.6"
      )

      response = provider.call(provider_request)

      assert_equal "We checked the order status.", response.body
      assert_equal "draft", response.status
      assert_equal 79, response.confidence
      assert_equal "order_status", response.category
      assert_equal [ "policy-1" ], response.source_references
      assert_equal "test-key", client.api_key
      assert_equal "https://example.test/v1", client.base_url
      assert_equal "accounts/fireworks/models/kimi-k2.6", client.payload.fetch(:model)
      assert_equal %w[system user], client.payload.fetch(:messages).map { |message| message.fetch(:role) }
      assert_match "Use 'we'", client.payload.fetch(:messages).first.fetch(:content)
      assert_match "Return only valid JSON", client.payload.fetch(:messages).first.fetch(:content)
      assert_match "Customer support request", client.payload.fetch(:messages).last.fetch(:content)
      assert_not response.failure?
    end

    test "uses env model before default model" do
      client = CapturingClient.new(success_response)
      provider = OpenaiCompatibleChatProvider.new(client: client, api_key: "test-key", model: "default/model")

      with_env("LLM_MODEL" => "env/model") do
        provider.call(provider_request)
      end

      assert_equal "env/model", client.payload.fetch(:model)
    end

    test "uses controlled failure when chat response is not structured JSON" do
      client = CapturingClient.new(
        "_http_status" => 200,
        "choices" => [ { "message" => { "content" => "We can help with that." } } ]
      )
      provider = OpenaiCompatibleChatProvider.new(client: client, api_key: "test-key")

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal "Bot response was not valid JSON.", response.review_reason
    end

    test "uses controlled failure when api key is missing" do
      provider = OpenaiCompatibleChatProvider.new(client: CapturingClient.new, api_key: nil)

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal 0, response.confidence
      assert_equal "LLM API key is not configured.", response.review_reason
    end

    test "uses controlled failure for non-success http response" do
      client = CapturingClient.new(
        "_http_status" => 429,
        "error" => { "message" => "rate limited" }
      )
      provider = OpenaiCompatibleChatProvider.new(client: client, api_key: "test-key")

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal "rate limited", response.review_reason
    end

    test "uses controlled failure for client exceptions" do
      provider = OpenaiCompatibleChatProvider.new(client: FailingClient.new, api_key: "test-key")

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "OpenAI-compatible provider call failed.", response.review_reason
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

    def success_response
      {
        "_http_status" => 200,
        "choices" => [
          {
            "message" => {
              "content" => JSON.generate(
                answer_text: "We checked the order status.",
                confidence: 0.79,
                category: "order_status",
                source_references: [],
                upload_requested: false,
                upload_type: nil,
                escalation_recommended: false,
                escalation_reason: nil
              )
            }
          }
        ]
      }
    end

    def with_env(values)
      previous_values = values.transform_values { |_value| nil }
      values.each do |key, value|
        previous_values[key] = ENV[key]
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end

      yield
    ensure
      previous_values.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end

    class CapturingClient
      attr_reader :api_key, :base_url, :payload

      def initialize(response = {})
        @response = response
      end

      def post_chat_completion(api_key:, base_url:, payload:)
        @api_key = api_key
        @base_url = base_url
        @payload = payload
        @response
      end
    end

    class FailingClient
      def post_chat_completion(api_key:, base_url:, payload:)
        raise "network unavailable"
      end
    end
  end
end
