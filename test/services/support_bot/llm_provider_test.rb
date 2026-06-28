require "test_helper"

module SupportBot
  class LlmProviderTest < ActiveSupport::TestCase
    test "uses controlled failure when api key is missing" do
      provider = LlmProvider.new(config: config(api_key: nil), client: QueueClient.new)

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal 0, response.confidence
      assert_equal "LLM API key is not configured.", response.review_reason
    end

    test "sends chat completion payload and parses structured response" do
      client = QueueClient.new([ chat_response(structured_json) ])
      provider = LlmProvider.new(config: config, client: client, tools: ToolRegistry.none)

      response = provider.call(provider_request)

      assert_not response.failure?
      assert_equal "We checked the order status.", response.body
      assert_equal "draft", response.status
      assert_equal 81, response.confidence
      assert_equal "order_status", response.category
      assert_equal [ "policy-1" ], response.source_references

      payload = client.payloads.first
      assert_equal "demo/model", payload[:model]
      assert_equal %w[system user], payload[:messages].map { |message| message[:role] }
      assert_match "Use 'we'", payload[:messages].first[:content]
      assert_match "Do not use first-person singular phrasing", payload[:messages].first[:content]
      assert_match "1-3 short sentences", payload[:messages].first[:content]
      assert_match "Do not tell the customer that a human, agent, or operator is helping behind the scenes", payload[:messages].first[:content]
      assert_match "When escalation_recommended is true", payload[:messages].first[:content]
      assert_match "Return only valid JSON", payload[:messages].first[:content]
      assert_match "Customer support request", payload[:messages].last[:content]
      assert_nil payload[:tools]
      assert_equal "test-key", client.api_keys.first
      assert_match "/chat/completions", client.urls.first
    end

    test "advertises tool schemas when tools are registered" do
      client = QueueClient.new([ chat_response(structured_json) ])
      provider = LlmProvider.new(config: config, client: client)

      provider.call(provider_request)

      tool_names = client.payloads.first[:tools].map { |tool| tool.dig(:function, :name) }
      assert_includes tool_names, "search_knowledge_base"
      assert_includes tool_names, "propose_refund"
    end

    test "executes a safe tool and feeds the result back before answering" do
      first = chat_response_with_tool_calls([
        tool_call("search_knowledge_base", "query" => "refund")
      ])
      client = QueueClient.new([ first, chat_response(structured_json) ])
      provider = LlmProvider.new(config: config, client: client)

      response = provider.call(provider_request)

      assert_not response.failure?
      assert_equal "We checked the order status.", response.body
      assert_equal 2, client.payloads.length

      second_messages = client.payloads.last[:messages]
      assert_includes second_messages.map { |message| message[:role] }, "tool"
      tool_message = second_messages.find { |message| message[:role] == "tool" }
      assert_match "Refund Policy", tool_message[:content]
    end

    test "proposes a sensitive action for operator review instead of executing it" do
      call = tool_call("propose_refund", "reason" => "Damaged on arrival", "order_reference" => "A123")
      client = QueueClient.new([ chat_response_with_tool_calls([ call ]) ])
      provider = LlmProvider.new(config: config, client: client)

      response = provider.call(provider_request)

      assert_equal "pending_review", response.status
      assert response.escalation_recommended
      assert_no_match(/operator|agent|human/i, response.body)
      assert_equal 1, response.proposed_actions.length
      assert_equal "refund", response.proposed_actions.first[:action_type]
      assert_equal "Damaged on arrival", response.proposed_actions.first[:arguments]["reason"]
      assert_equal 1, client.payloads.length, "should stop after proposing, with no execution round-trip"
    end

    test "uses controlled failure when chat response is not structured JSON" do
      client = QueueClient.new([ chat_response("We can help with that.") ])
      provider = LlmProvider.new(config: config, client: client, tools: ToolRegistry.none)

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal "Bot response was not valid JSON.", response.review_reason
      assert_no_match(/operator|agent|human/i, response.body)
    end

    test "uses controlled failure for non-success http response" do
      client = QueueClient.new([ { "_http_status" => 429, "error" => { "message" => "rate limited" } } ])
      provider = LlmProvider.new(config: config, client: client, tools: ToolRegistry.none)

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "pending_review", response.status
      assert_equal "rate limited", response.review_reason
    end

    test "uses controlled failure for client exceptions" do
      provider = LlmProvider.new(config: config, client: FailingClient.new, tools: ToolRegistry.none)

      response = provider.call(provider_request)

      assert response.failure?
      assert_equal "LLM provider call failed.", response.review_reason
      assert_match "RuntimeError", response.raw_provider_response
    end

    test "fails when the model exceeds the tool-call iteration limit" do
      looping = chat_response_with_tool_calls([ tool_call("lookup_order_status", "order_reference" => "A1") ])
      client = AlwaysToolClient.new(looping)
      provider = LlmProvider.new(config: config, client: client)

      response = provider.call(provider_request)

      assert response.failure?
      assert_match "iteration limit", response.review_reason
      assert_equal LlmProvider::MAX_TOOL_ITERATIONS, client.calls
    end

    test "feeds an error back and continues when the model calls an unknown tool" do
      first = chat_response_with_tool_calls([ tool_call("do_magic", "x" => 1) ])
      client = QueueClient.new([ first, chat_response(structured_json) ])
      provider = LlmProvider.new(config: config, client: client)

      response = provider.call(provider_request)

      assert_not response.failure?
      assert_equal "We checked the order status.", response.body
      assert_equal 2, client.payloads.length
      tool_message = client.payloads.last[:messages].find { |message| message[:role] == "tool" }
      assert_match "Unknown tool", tool_message[:content]
    end

    test "feeds the error back and still answers when a safe tool raises" do
      raising = Tool.new(name: "boom", description: "always fails") { |_arguments, _context| raise "kaboom" }
      registry = ToolRegistry.new([ raising ])
      first = chat_response_with_tool_calls([ tool_call("boom", {}) ])
      client = QueueClient.new([ first, chat_response(structured_json) ])
      provider = LlmProvider.new(config: config, client: client, tools: registry)

      response = provider.call(provider_request)

      assert_not response.failure?
      assert_equal "We checked the order status.", response.body
      tool_message = client.payloads.last[:messages].find { |message| message[:role] == "tool" }
      assert_match "failed", tool_message[:content]
      assert_match "kaboom", tool_message[:content]
    end

    test "accumulates multiple proposed actions from a single turn and stops" do
      calls = [
        tool_call("propose_refund", "reason" => "Damaged"),
        tool_call("propose_return", "reason" => "Wrong size")
      ]
      client = QueueClient.new([ chat_response_with_tool_calls(calls) ])
      provider = LlmProvider.new(config: config, client: client)

      response = provider.call(provider_request)

      assert_equal "pending_review", response.status
      assert_equal %w[refund return], response.proposed_actions.map { |action| action[:action_type] }
      assert_equal 1, client.payloads.length
    end

    test "preserves raw arguments when a proposed action's tool arguments are malformed" do
      malformed = { "id" => "call_x", "type" => "function", "function" => { "name" => "propose_refund", "arguments" => "{not json" } }
      client = QueueClient.new([ chat_response_with_tool_calls([ malformed ]) ])
      provider = LlmProvider.new(config: config, client: client)

      response = provider.call(provider_request)

      assert_equal "pending_review", response.status
      action = response.proposed_actions.first
      assert_equal "refund", action[:action_type]
      assert_equal "{not json", action[:arguments]["_raw"]
      assert action[:arguments]["_parse_error"]
    end

    private

    def config(name: "openai_compatible", api_key: "test-key", base_url: "https://example.test/v1", model: "demo/model")
      ProviderConfig::Profile.new(name: name, api_key: api_key, base_url: base_url, model: model)
    end

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

    def structured_json
      JSON.generate(
        answer_text: "We checked the order status.",
        confidence: 0.81,
        category: "order_status",
        source_references: [ "policy-1" ],
        upload_requested: false,
        upload_type: nil,
        escalation_recommended: false,
        escalation_reason: nil
      )
    end

    def chat_response(content)
      { "_http_status" => 200, "choices" => [ { "message" => { "content" => content } } ] }
    end

    def chat_response_with_tool_calls(tool_calls)
      { "_http_status" => 200, "choices" => [ { "message" => { "content" => nil, "tool_calls" => tool_calls } } ] }
    end

    def tool_call(name, arguments)
      {
        "id" => "call_#{name}",
        "type" => "function",
        "function" => { "name" => name, "arguments" => JSON.generate(arguments) }
      }
    end

    class QueueClient
      attr_reader :payloads, :api_keys, :urls

      def initialize(responses = [])
        @responses = responses.dup
        @payloads = []
        @api_keys = []
        @urls = []
      end

      def post_json(url:, api_key:, payload:)
        @urls << url
        @api_keys << api_key
        @payloads << payload
        raise "no more queued responses" if @responses.empty?

        @responses.shift
      end
    end

    class FailingClient
      def post_json(url:, api_key:, payload:)
        raise "network unavailable"
      end
    end

    class AlwaysToolClient
      attr_reader :calls

      def initialize(response)
        @response = response
        @calls = 0
      end

      def post_json(url:, api_key:, payload:)
        @calls += 1
        @response
      end
    end
  end
end
