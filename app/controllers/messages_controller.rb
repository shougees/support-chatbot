class MessagesController < ApplicationController
  before_action :set_conversation

  def create
    @message = @conversation.messages.build(message_params)
    @message.public_role = "customer"
    @message.origin = "customer_submitted"

    if create_message
      redirect_to conversation_path(@conversation.public_id)
    else
      @messages = @conversation.messages.chronological
      render "conversations/show", status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find_by!(public_id: params[:conversation_public_id])
  end

  def message_params
    params.require(:message).permit(:body)
  end

  def create_message
    @conversation.with_lock do
      @message.position = next_position
      @message.save
    end
  end

  def next_position
    @conversation.messages.maximum(:position).to_i + 1
  end
end
