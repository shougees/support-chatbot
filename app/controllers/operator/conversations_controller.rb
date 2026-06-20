module Operator
  class ConversationsController < ApplicationController
    def show
      @conversation = Conversation.find_by!(public_id: params[:public_id])
      @messages = @conversation.messages.includes(:author, :published_by, :response_draft, retrieval_results: :knowledge_document).chronological
      @response_drafts = @conversation.response_drafts.includes(:bot_agent, :published_message, :response_reviews).order(:created_at, :id)
      @direct_message = Message.new
    end
  end
end
