module SupportBot
  # Assembles the system instructions and the initial chat messages sent to
  # the LLM. This guidance used to be duplicated verbatim inside each
  # provider; it now lives here once so the prompt can evolve in one place.
  class PromptBuilder
    GUIDANCE = [
      "Use concise ecommerce support language.",
      "Use 'we' instead of first-person singular language.",
      "Do not claim that a real refund, return, account, or delivery action was completed.",
      "If policy or context is insufficient, set escalation_recommended to true.",
      "When tools are available, search the knowledge base before answering policy questions, " \
        "and propose (never assume) sensitive actions such as refunds or returns.",
      "Treat tool results such as order status as unverified reference signals, not confirmed facts; " \
        "never state a delivery or account status as confirmed, and offer escalation when certainty is required."
    ].freeze

    def self.system_instructions(request)
      [
        request.bot_agent&.system_prompt,
        *GUIDANCE,
        ResponseContract.instructions
      ].compact.join("\n")
    end

    # OpenAI-compatible chat message array used to seed the conversation. The
    # provider appends assistant/tool messages to this list as the tool loop
    # runs.
    def self.messages(request)
      [
        { role: "system", content: system_instructions(request) },
        { role: "user", content: request.prompt_text }
      ]
    end
  end
end
