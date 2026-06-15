class ConversationsController < ApplicationController
  def show
    @conversation = Conversation.find_by!(public_id: params[:public_id])
    @messages = @conversation.messages.chronological
    @message = @conversation.messages.build(public_role: "customer", origin: "customer_submitted")
  end
end
