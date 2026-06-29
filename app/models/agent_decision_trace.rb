class AgentDecisionTrace < ApplicationRecord
  OUTCOMES = %w[answered_directly upload_requested action_proposed human_review_requested fallback].freeze

  belongs_to :conversation
  belongs_to :message
  belongs_to :bot_agent, optional: true
  belongs_to :response_draft, optional: true
  belongs_to :response_review, optional: true
  belongs_to :published_message, class_name: "Message", optional: true

  validates :outcome, presence: true, inclusion: { in: OUTCOMES }
  validates :message_id, uniqueness: true
  validate :message_belongs_to_conversation

  def retrieved_document_ids
    parse_json_array(retrieved_knowledge_document_ids)
  end

  def proposed_tools
    parse_json_array(proposed_tool_names)
  end

  def proposed_actions
    parse_json_array(proposed_action_types)
  end

  def metadata_hash
    JSON.parse(metadata.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  private

  def message_belongs_to_conversation
    return if message.blank? || conversation.blank? || message.conversation_id == conversation_id

    errors.add(:message, "must belong to conversation")
  end

  def parse_json_array(value)
    parsed = JSON.parse(value.presence || "[]")
    parsed.is_a?(Array) ? parsed : []
  rescue JSON::ParserError
    []
  end
end
