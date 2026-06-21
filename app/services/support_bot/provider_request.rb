module SupportBot
  ProviderRequest = Struct.new(:conversation, :message, :bot_agent, :retrieved_documents, keyword_init: true) do
    HISTORY_LIMIT = 8

    def recent_messages
      conversation
        .customer_visible_messages
        .last(HISTORY_LIMIT)
        .map { |conversation_message| message_payload(conversation_message) }
    end

    def knowledge_context
      retrieved_documents.map do |document|
        {
          id: document.id,
          title: document.title,
          category: document.category,
          body: document.body.presence || document.extracted_text.to_s
        }
      end
    end

    def prompt_text
      <<~PROMPT
        Customer support request:
        #{message.body}

        Recent conversation:
        #{recent_messages.map { |item| "- #{item[:role]}: #{item[:body]}" }.join("\n")}

        Retrieved knowledge:
        #{knowledge_context.map { |item| "- #{item[:title]}: #{item[:body]}" }.join("\n")}
      PROMPT
    end

    private

    def message_payload(conversation_message)
      {
        role: conversation_message.customer? ? "customer" : "support",
        body: conversation_message.body
      }
    end
  end
end
