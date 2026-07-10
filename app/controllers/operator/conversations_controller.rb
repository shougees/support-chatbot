module Operator
  class ConversationsController < ApplicationController
    FILTERS = %w[all escalated pending_review open closed].freeze

    def index
      @filter = params[:filter].presence_in(FILTERS) || "all"
      @conversations = filtered_conversations
    end

    def show
      @conversation = Conversation.find_by!(public_id: params[:public_id])
      @direct_message = Message.new
    end

    private

    def filtered_conversations
      conversations = Conversation
        .includes(
          :escalations,
          :response_reviews,
          :uploads,
          messages: [ :feedbacks, :retrieval_results, :agent_decision_trace ]
        )

      conversations = case @filter
      when "escalated"
        conversations.joins(:escalations).merge(Escalation.active).distinct
      when "pending_review"
        conversations.joins(:response_reviews).merge(ResponseReview.pending).distinct
      when "open"
        conversations.where.not(status: "closed")
      when "closed"
        conversations.closed
      else
        conversations
      end

      conversations.order(updated_at: :desc, created_at: :desc)
    end
  end
end
