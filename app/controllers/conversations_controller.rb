class ConversationsController < ApplicationController
  def create
    conversation = Conversation.create!

    redirect_to conversation_path(conversation.public_id)
  end

  def show
    @conversation = Conversation.find_by!(public_id: params[:public_id])
    @messages = @conversation.messages.chronological
    @message = @conversation.messages.build(public_role: "customer", origin: "customer_submitted")
  end
end
