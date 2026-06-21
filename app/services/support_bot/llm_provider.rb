module SupportBot
  # The single runtime LLM provider.
  #
  # It speaks the OpenAI-compatible chat-completions wire format against any
  # configured base URL (OpenAI, Fireworks, Kimi/Moonshot, ...), runs a bounded
  # tool-calling loop, and returns a validated structured {ProviderResponse}.
  # This replaces the previous `OpenaiProvider` (Responses API) and
  # `OpenaiCompatibleChatProvider` (Chat Completions API), which were ~80%
  # identical.
  #
  # Tool loop:
  #   1. Send messages + tool schemas to the model.
  #   2. If the model calls *safe* tools, execute them and feed results back,
  #      then loop (up to {MAX_TOOL_ITERATIONS}).
  #   3. If the model calls a *sensitive* tool, stop and return a
  #      review-required response carrying the proposed action(s).
  #   4. Otherwise parse the final message against {ResponseContract}.
  class LlmProvider
    MAX_TOOL_ITERATIONS = 4
    DEFAULT_TEMPERATURE = 0.2

    def initialize(config:, client: HttpClient.new, tools: ToolRegistry.default, temperature: DEFAULT_TEMPERATURE)
      @config = config
      @client = client
      @tools = tools
      @temperature = temperature
    end

    def call(request)
      return missing_key_failure if config.api_key.blank?

      messages = PromptBuilder.messages(request)
      proposed_actions = []
      last_raw = nil

      MAX_TOOL_ITERATIONS.times do
        raw = client.post_json(url: endpoint_url, api_key: config.api_key, payload: payload(messages))
        last_raw = raw
        return http_failure(raw) unless success?(raw)

        message = raw.dig("choices", 0, "message") || {}
        tool_calls = Array(message["tool_calls"])

        if tool_calls.any?
          messages << assistant_tool_message(message)
          break if dispatch_tool_calls(tool_calls, request, messages, proposed_actions)

          next
        end

        return action_review_response(proposed_actions, raw) if proposed_actions.any?

        text = extract_text(message)
        return ProviderResponse.failure("LLM response did not include answer text.", raw_provider_response: raw.to_json) if text.blank?

        return StructuredResponseParser.call(text, raw_provider_response: raw)
      end

      return action_review_response(proposed_actions, last_raw) if proposed_actions.any?

      ProviderResponse.failure("LLM exceeded the tool-call iteration limit.", raw_provider_response: last_raw.to_json)
    rescue JSON::ParserError => error
      ProviderResponse.failure("LLM returned invalid JSON.", raw_provider_response: "#{error.class}: #{error.message}")
    rescue StandardError => error
      ProviderResponse.failure("LLM provider call failed.", raw_provider_response: "#{error.class}: #{error.message}")
    end

    private

    attr_reader :config, :client, :tools, :temperature

    # Returns true when the loop should stop (a sensitive action was proposed).
    def dispatch_tool_calls(tool_calls, request, messages, proposed_actions)
      stop = false

      tool_calls.each do |tool_call|
        name = tool_call.dig("function", "name")
        tool = tools.fetch(name)
        arguments = parse_arguments(tool_call.dig("function", "arguments"))

        if tool.nil?
          messages << tool_result_message(tool_call, "Unknown tool: #{name}.")
        elsif tool.sensitive?
          proposed_actions << { action_type: tool.action_type, name: tool.name, arguments: arguments }
          stop = true
        else
          messages << tool_result_message(tool_call, safe_execute(tool, arguments, request))
        end
      end

      stop
    end

    def safe_execute(tool, arguments, request)
      tool.execute(arguments, request)
    rescue StandardError => error
      "Tool #{tool.name} failed: #{error.class}: #{error.message}"
    end

    def payload(messages)
      body = {
        model: config.model,
        messages: messages,
        temperature: temperature
      }
      body[:tools] = tools.schemas unless tools.empty?
      body
    end

    def endpoint_url
      base = config.base_url.to_s.chomp("/")
      base.end_with?("/chat/completions") ? base : "#{base}/chat/completions"
    end

    def assistant_tool_message(message)
      { role: "assistant", content: message["content"], tool_calls: message["tool_calls"] }
    end

    def tool_result_message(tool_call, content)
      {
        role: "tool",
        tool_call_id: tool_call["id"],
        name: tool_call.dig("function", "name"),
        content: content.to_s
      }
    end

    def parse_arguments(raw_arguments)
      return {} if raw_arguments.blank?
      return raw_arguments if raw_arguments.is_a?(Hash)

      JSON.parse(raw_arguments)
    rescue JSON::ParserError
      # Preserve the model's intent so a proposed sensitive action still
      # reaches the operator (and audit trail) with context, rather than an
      # empty hash that silently loses the stated reason.
      { "_raw" => raw_arguments.to_s, "_parse_error" => true }
    end

    def action_review_response(proposed_actions, raw)
      action_labels = proposed_actions.map { |action| action[:action_type] }.uniq.join(", ")
      reason = "The bot proposed #{action_labels} which require operator review before any action is taken."

      ProviderResponse.new(
        body: "We've noted this request, and a support operator will review the next step before we proceed.",
        confidence: 50,
        category: "action_proposal",
        status: "pending_review",
        review_reason: reason,
        upload_requested: false,
        source_references: [],
        escalation_recommended: true,
        escalation_reason: reason,
        proposed_actions: proposed_actions,
        raw_provider_response: raw.is_a?(String) ? raw : JSON.generate(raw)
      )
    end

    def extract_text(message)
      content = message["content"]
      return content if content.is_a?(String)

      Array(content).filter_map do |item|
        next item if item.is_a?(String)
        next unless item.is_a?(Hash)

        text = item["text"]
        text.is_a?(String) ? text : item.dig("text", "value")
      end.join
    end

    def success?(raw_response)
      raw_response.fetch("_http_status").between?(200, 299)
    end

    def http_failure(raw_response)
      message = raw_response.dig("error", "message").presence ||
        "#{config.label} provider returned HTTP #{raw_response.fetch('_http_status')}."
      ProviderResponse.failure(message, raw_provider_response: raw_response.to_json)
    end

    def missing_key_failure
      ProviderResponse.failure(
        "#{config.label} API key is not configured.",
        raw_provider_response: "missing_#{config.name}_api_key"
      )
    end
  end
end
